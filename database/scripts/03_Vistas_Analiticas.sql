/* ============================================================================
   CASO 2 - BIKE Z | FASE 2
   Script 03: Vistas analíticas sobre DW_BikeZ
   ----------------------------------------------------------------------------
   Propósito:
     Exponer el modelo estrella a la capa de análisis (cubo OLAP en SSAS y
     dashboard en Power BI) agregando atributos derivados que NO cambian el
     grano del modelo ni la carga ETL:
       - DimTiempo   : claves y nombres únicos por nivel (jerarquía Calendario).
       - DimProducto : grupo de categoría (jerarquía Grupo > Categoría > Producto).
       - DimVendedor : nombre del vendedor, tipo de venta, antigüedad, edad y
                       rangos de análisis (KPI 4).
       - FactVentas  : indicadores a nivel de orden para el KPI 2 (despacho) y
                       el conteo de órdenes sin duplicar por línea.
   Reglas:
     - La fecha de referencia para antigüedad y edad es la última fecha de
       pedido registrada en FactVentas (cierre del período de datos).
     - Re-ejecutable: CREATE OR ALTER VIEW (SQL Server 2016 SP1 o superior).
   ============================================================================ */

USE DW_BikeZ;
GO

/* ----------------------------------------------------------------------------
   1. vw_DimTiempo
   Cada nivel de la jerarquía necesita una clave única (no se repite entre
   años) y un nombre legible. Ej.: TrimestreKey = 20173 -> "T3 2017".
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_DimTiempo
AS
SELECT
    t.TiempoKey,
    t.Fecha,
    t.Anio,
    CAST(t.Anio AS NVARCHAR(4))                                         AS AnioNombre,
    t.Anio * 10 + t.Semestre                                            AS SemestreKey,
    N'S' + CAST(t.Semestre AS NVARCHAR(1)) + N' ' + CAST(t.Anio AS NVARCHAR(4))  AS SemestreNombre,
    t.Anio * 10 + t.Trimestre                                           AS TrimestreKey,
    N'T' + CAST(t.Trimestre AS NVARCHAR(1)) + N' ' + CAST(t.Anio AS NVARCHAR(4)) AS TrimestreNombre,
    t.Anio * 100 + t.Mes                                                AS MesKey,
    t.NombreMes + N' ' + CAST(t.Anio AS NVARCHAR(4))                    AS MesNombre,
    t.Semestre,
    t.Trimestre,
    t.Mes,
    t.NombreMes,
    t.Dia,
    t.NombreDia,
    CONVERT(NVARCHAR(10), t.Fecha, 105)                                 AS FechaNombre   -- dd-mm-aaaa
FROM dbo.DimTiempo AS t;
GO

/* ----------------------------------------------------------------------------
   2. vw_DimProducto
   Agrega GrupoCategoria (regla de negocio definida por el equipo) para
   agrupar las 37 categorías en 4 familias + "Sin Categoría".
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_DimProducto
AS
SELECT
    p.ProductoKey,
    p.ProductoID,
    p.NombreProducto,
    p.Color,
    p.CategoriaID,
    p.NombreCategoria,
    CASE
        WHEN p.NombreCategoria IN (N'Mountain Bikes', N'Road Bikes', N'Touring Bikes')
            THEN N'Bicicletas'
        WHEN p.NombreCategoria IN (N'Mountain Frames', N'Road Frames', N'Touring Frames',
                                   N'Wheels', N'Handlebars', N'Bottom Brackets', N'Brakes',
                                   N'Chains', N'Cranksets', N'Derailleurs', N'Forks',
                                   N'Headsets', N'Pedals', N'Saddles')
            THEN N'Componentes'
        WHEN p.NombreCategoria IN (N'Bib-Shorts', N'Caps', N'Gloves', N'Jerseys',
                                   N'Shorts', N'Socks', N'Tights', N'Vests')
            THEN N'Vestuario'
        WHEN p.NombreCategoria = N'Sin Categoría'
            THEN N'Sin Categoría'
        ELSE N'Accesorios'
    END AS GrupoCategoria
FROM dbo.DimProducto AS p;
GO

/* ----------------------------------------------------------------------------
   3. vw_DimCliente (paso directo, se expone por consistencia de la capa)
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_DimCliente
AS
SELECT ClienteKey, ClienteID, Nombre, Apellido, NombreCompleto
FROM dbo.DimCliente;
GO

/* ----------------------------------------------------------------------------
   4. vw_DimTerritorio (paso directo + etiqueta de almacenes)
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_DimTerritorio
AS
SELECT
    TerritorioKey,
    TerritorioID,
    NombreTerritorio,
    Grupo,
    PaisID,
    NombrePais,
    CantidadAlmacenes
FROM dbo.DimTerritorio;
GO

/* ----------------------------------------------------------------------------
   5. vw_DimVendedor
   - NombreVendedor: la tabla Empleados no tiene nombre, se construye una
     etiqueta "Vendedor <ID> - <Cargo>".
   - TipoVenta: separa las ventas directas (registro dummy -1) de las
     gestionadas por un vendedor.
   - Antigüedad y edad en años a la fecha de cierre de los datos.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_DimVendedor
AS
WITH Ref AS (
    SELECT MAX(t.Fecha) AS FechaReferencia
    FROM dbo.FactVentas AS f
    INNER JOIN dbo.DimTiempo AS t ON t.TiempoKey = f.FechaPedidoKey
),
Base AS (
    SELECT
        v.*,
        CASE WHEN v.EmpleadoID = -1 THEN NULL
             ELSE CAST(DATEDIFF(MONTH, v.FechaContratacion, r.FechaReferencia) / 12.0 AS DECIMAL(5,1))
        END AS AniosAntiguedad,
        CASE WHEN v.EmpleadoID = -1 THEN NULL
             ELSE DATEDIFF(MONTH, v.FechaNacimiento, r.FechaReferencia) / 12
        END AS Edad
    FROM dbo.DimVendedor AS v
    CROSS JOIN Ref AS r
)
SELECT
    VendedorKey,
    EmpleadoID,
    CASE WHEN EmpleadoID = -1 THEN N'Sin Vendedor (Venta Directa)'
         ELSE N'Vendedor ' + CAST(EmpleadoID AS NVARCHAR(10)) + N' - ' + Cargo
    END AS NombreVendedor,
    CASE WHEN EmpleadoID = -1 THEN N'Venta Directa' ELSE N'Con Vendedor' END AS TipoVenta,
    Cargo,
    CASE Genero      WHEN N'M' THEN N'Masculino' WHEN N'F' THEN N'Femenino' ELSE N'No aplica' END AS Genero,
    CASE EstadoCivil WHEN N'M' THEN N'Casado(a)' WHEN N'S' THEN N'Soltero(a)' ELSE N'No aplica' END AS EstadoCivil,
    FechaNacimiento,
    FechaContratacion,
    HorasVacaciones,
    AniosAntiguedad,
    Edad,
    CASE WHEN EmpleadoID = -1         THEN N'No aplica'
         WHEN AniosAntiguedad < 16    THEN N'1. Menos de 16 años'
         WHEN AniosAntiguedad < 17    THEN N'2. Entre 16 y 17 años'
         ELSE                              N'3. 17 años o más'
    END AS RangoAntiguedad,
    CASE WHEN EmpleadoID = -1         THEN N'No aplica'
         WHEN HorasVacaciones < 25    THEN N'1. Menos de 25 h'
         WHEN HorasVacaciones < 35    THEN N'2. Entre 25 y 34 h'
         ELSE                              N'3. 35 h o más'
    END AS RangoHorasVacaciones,
    CASE WHEN EmpleadoID = -1         THEN N'No aplica'
         WHEN Edad < 50               THEN N'1. Menos de 50 años'
         WHEN Edad < 60               THEN N'2. Entre 50 y 59 años'
         ELSE                              N'3. 60 años o más'
    END AS RangoEdad
FROM Base;
GO

/* ----------------------------------------------------------------------------
   6. vw_FactVentas
   Mantiene el grano (línea de venta) y agrega columnas a nivel de orden.
   Como DiasDespacho se repite en todas las líneas de una orden, sólo la
   PRIMERA línea de cada orden aporta al cálculo del KPI 2:
     EsPrimeraLineaOrden = 1 en la primera línea de la orden, 0 en el resto.
     DiasDespachoOrden   = DiasDespacho en la primera línea, 0 en el resto.
     EsDespachoTardio    = 1 si la orden tardó más de 7 días (meta logística).
   Así, SUM(DiasDespachoOrden) / SUM(EsPrimeraLineaOrden) = promedio por orden.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_FactVentas
AS
WITH Lineas AS (
    SELECT
        f.*,
        ROW_NUMBER() OVER (PARTITION BY f.VentaID ORDER BY f.DetalleVentaID) AS NumeroLinea
    FROM dbo.FactVentas AS f
)
SELECT
    FactVentaKey,
    ProductoKey,
    ClienteKey,
    VendedorKey,
    TerritorioKey,
    FechaPedidoKey,
    FechaEnvioKey,
    VentaID,
    DetalleVentaID,
    Cantidad,
    PrecioUnitario,
    MontoTotalLinea,
    DiasDespacho,
    CAST(CASE WHEN NumeroLinea = 1 THEN 1 ELSE 0 END AS INT)                          AS EsPrimeraLineaOrden,
    CAST(CASE WHEN NumeroLinea = 1 THEN DiasDespacho ELSE 0 END AS INT)               AS DiasDespachoOrden,
    CAST(CASE WHEN NumeroLinea = 1 AND DiasDespacho > 7 THEN 1 ELSE 0 END AS INT)     AS EsDespachoTardio
FROM Lineas;
GO

/* ----------------------------------------------------------------------------
   7. Verificación rápida de las vistas (los totales deben coincidir con la
      validación de la Fase 1)
   ---------------------------------------------------------------------------- */
SELECT
    COUNT(*)                                   AS LineasVenta,           -- 121.317
    SUM(Cantidad)                              AS UnidadesVendidas,      -- 274.914
    SUM(MontoTotalLinea)                       AS MontoTotal,            -- 110.373.033,93
    SUM(EsPrimeraLineaOrden)                   AS Ordenes,               -- 31.465
    CAST(SUM(DiasDespachoOrden) * 1.0
         / SUM(EsPrimeraLineaOrden) AS DECIMAL(6,2)) AS DiasPromedioDespacho, -- 6,99
    SUM(EsDespachoTardio)                      AS OrdenesDespachoTardio  -- 58
FROM dbo.vw_FactVentas;

SELECT GrupoCategoria, COUNT(*) AS Productos
FROM dbo.vw_DimProducto
GROUP BY GrupoCategoria
ORDER BY GrupoCategoria;

SELECT TOP (20) NombreVendedor, TipoVenta, AniosAntiguedad, RangoAntiguedad, RangoHorasVacaciones
FROM dbo.vw_DimVendedor
WHERE Cargo LIKE N'%Sales%' OR EmpleadoID = -1
ORDER BY EmpleadoID;
GO
