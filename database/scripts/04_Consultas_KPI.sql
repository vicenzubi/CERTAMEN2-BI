/* ============================================================================
   CASO 2 - BIKE Z | FASE 2
   Script 04: Cálculo de los KPI directamente en SQL (valores de referencia)
   ----------------------------------------------------------------------------
   Sirve para:
     1. Conocer los valores esperados de cada KPI.
     2. Validar que el cubo OLAP (SSAS) y el dashboard (Power BI) entregan
        exactamente las mismas cifras ("cuadratura" de la capa analítica).
   Requiere: 03_Vistas_Analiticas.sql ejecutado.
   ============================================================================ */

USE DW_BikeZ;
GO

/* ----------------------------------------------------------------------------
   Totales generales (referencia para cualquier visual sin filtros)
   ---------------------------------------------------------------------------- */
SELECT
    SUM(f.MontoTotalLinea)                                   AS Ingresos,          -- 110.373.033,93
    SUM(f.Cantidad)                                          AS Unidades,          -- 274.914
    COUNT(DISTINCT f.VentaID)                                AS Ordenes,           -- 31.465
    SUM(f.MontoTotalLinea) / COUNT(DISTINCT f.VentaID)       AS TicketPromedio     -- 3.507,80
FROM dbo.vw_FactVentas AS f;

/* ----------------------------------------------------------------------------
   KPI 1. Crecimiento de ingresos por ventas (%)
   1.a Por año (ojo: 2015 sólo tiene jul-dic y 2018 sólo ene-jul)
   ---------------------------------------------------------------------------- */
WITH IngresosAnio AS (
    SELECT t.Anio, SUM(f.MontoTotalLinea) AS Ingresos, COUNT(DISTINCT t.Mes) AS MesesConVentas
    FROM dbo.vw_FactVentas AS f
    INNER JOIN dbo.vw_DimTiempo AS t ON t.TiempoKey = f.FechaPedidoKey
    GROUP BY t.Anio
)
SELECT
    Anio, MesesConVentas, Ingresos,
    LAG(Ingresos) OVER (ORDER BY Anio) AS IngresosAnioAnterior,
    CAST(100.0 * (Ingresos - LAG(Ingresos) OVER (ORDER BY Anio))
         / NULLIF(LAG(Ingresos) OVER (ORDER BY Anio), 0) AS DECIMAL(9,2)) AS CrecimientoPct
FROM IngresosAnio
ORDER BY Anio;
-- 2017 vs 2016 (únicos años completos): +37,10 %

/* 1.b Por mes: variación vs mes anterior y vs mismo mes del año anterior */
WITH IngresosMes AS (
    SELECT t.MesKey, t.MesNombre, SUM(f.MontoTotalLinea) AS Ingresos
    FROM dbo.vw_FactVentas AS f
    INNER JOIN dbo.vw_DimTiempo AS t ON t.TiempoKey = f.FechaPedidoKey
    GROUP BY t.MesKey, t.MesNombre
)
SELECT
    MesKey, MesNombre, Ingresos,
    CAST(100.0 * (Ingresos - LAG(Ingresos, 1)  OVER (ORDER BY MesKey)) / NULLIF(LAG(Ingresos, 1)  OVER (ORDER BY MesKey), 0) AS DECIMAL(9,2)) AS CrecVsMesAnteriorPct,
    CAST(100.0 * (Ingresos - LAG(Ingresos, 12) OVER (ORDER BY MesKey)) / NULLIF(LAG(Ingresos, 12) OVER (ORDER BY MesKey), 0) AS DECIMAL(9,2)) AS CrecInteranualPct
FROM IngresosMes
ORDER BY MesKey;

/* 1.c Comparación de períodos equivalentes (enero a junio) */
SELECT
    t.Anio,
    SUM(f.MontoTotalLinea) AS IngresosEneJun
FROM dbo.vw_FactVentas AS f
INNER JOIN dbo.vw_DimTiempo AS t ON t.TiempoKey = f.FechaPedidoKey
WHERE t.Mes <= 6
GROUP BY t.Anio
ORDER BY t.Anio;
-- 2018 vs 2017 (ene-jun): 25.819.005,94 vs 15.047.677,36 = +71,58 %

/* 1.d Por país y año */
SELECT
    te.Grupo, te.NombrePais, t.Anio, SUM(f.MontoTotalLinea) AS Ingresos
FROM dbo.vw_FactVentas AS f
INNER JOIN dbo.vw_DimTiempo     AS t  ON t.TiempoKey      = f.FechaPedidoKey
INNER JOIN dbo.vw_DimTerritorio AS te ON te.TerritorioKey = f.TerritorioKey
GROUP BY te.Grupo, te.NombrePais, t.Anio
ORDER BY te.Grupo, te.NombrePais, t.Anio;

/* ----------------------------------------------------------------------------
   KPI 2. Tiempo promedio de despacho (días), calculado POR ORDEN
   ---------------------------------------------------------------------------- */
SELECT
    te.Grupo, te.NombrePais, te.NombreTerritorio,
    SUM(f.EsPrimeraLineaOrden)                                                    AS Ordenes,
    CAST(SUM(f.DiasDespachoOrden) * 1.0 / SUM(f.EsPrimeraLineaOrden) AS DECIMAL(6,3)) AS DiasPromedio,
    SUM(f.EsDespachoTardio)                                                       AS OrdenesTardias
FROM dbo.vw_FactVentas AS f
INNER JOIN dbo.vw_DimTerritorio AS te ON te.TerritorioKey = f.TerritorioKey
GROUP BY ROLLUP (te.Grupo, te.NombrePais, te.NombreTerritorio)
ORDER BY te.Grupo, te.NombrePais, te.NombreTerritorio;
-- Total: 6,989 días; 58 órdenes con más de 7 días

/* Distribución de días de despacho por orden */
SELECT DiasDespachoOrden AS Dias, COUNT(*) AS Ordenes
FROM dbo.vw_FactVentas
WHERE EsPrimeraLineaOrden = 1
GROUP BY DiasDespachoOrden
ORDER BY Dias;
-- 6 días: 412 | 7 días: 30.995 | 8 días: 58

/* ----------------------------------------------------------------------------
   KPI 3. Ingresos, volumen y participación por categoría de producto
   ---------------------------------------------------------------------------- */
SELECT
    p.GrupoCategoria, p.NombreCategoria,
    SUM(f.MontoTotalLinea) AS Ingresos,
    SUM(f.Cantidad)        AS Unidades,
    CAST(100.0 * SUM(f.MontoTotalLinea) / SUM(SUM(f.MontoTotalLinea)) OVER () AS DECIMAL(6,2)) AS ParticipacionPct
FROM dbo.vw_FactVentas AS f
INNER JOIN dbo.vw_DimProducto AS p ON p.ProductoKey = f.ProductoKey
GROUP BY p.GrupoCategoria, p.NombreCategoria
ORDER BY Ingresos DESC;
-- Road Bikes 39,85 % | Mountain Bikes 33,18 % | Touring Bikes 13,18 %

SELECT TOP (10) p.NombreProducto, p.NombreCategoria, SUM(f.MontoTotalLinea) AS Ingresos, SUM(f.Cantidad) AS Unidades
FROM dbo.vw_FactVentas AS f
INNER JOIN dbo.vw_DimProducto AS p ON p.ProductoKey = f.ProductoKey
GROUP BY p.NombreProducto, p.NombreCategoria
ORDER BY Ingresos DESC;

/* ----------------------------------------------------------------------------
   KPI 4. Rendimiento comercial y ticket promedio por vendedor
   ---------------------------------------------------------------------------- */
SELECT
    v.TipoVenta,
    SUM(f.MontoTotalLinea)                                AS Ingresos,
    COUNT(DISTINCT f.VentaID)                             AS Ordenes,
    SUM(f.MontoTotalLinea) / COUNT(DISTINCT f.VentaID)    AS TicketPromedio
FROM dbo.vw_FactVentas AS f
INNER JOIN dbo.vw_DimVendedor AS v ON v.VendedorKey = f.VendedorKey
GROUP BY v.TipoVenta;
-- Con Vendedor: 3.807 órdenes, ticket 21.281,26 | Venta Directa: 27.658 órdenes, ticket 1.061,37

SELECT
    v.NombreVendedor, v.RangoAntiguedad, v.RangoHorasVacaciones,
    SUM(f.MontoTotalLinea)                                AS Ingresos,
    COUNT(DISTINCT f.VentaID)                             AS Ordenes,
    SUM(f.MontoTotalLinea) / COUNT(DISTINCT f.VentaID)    AS TicketPromedio
FROM dbo.vw_FactVentas AS f
INNER JOIN dbo.vw_DimVendedor AS v ON v.VendedorKey = f.VendedorKey
WHERE v.TipoVenta = N'Con Vendedor'
GROUP BY v.NombreVendedor, v.RangoAntiguedad, v.RangoHorasVacaciones
ORDER BY Ingresos DESC;

SELECT
    v.RangoAntiguedad,
    COUNT(DISTINCT v.VendedorKey)                                        AS Vendedores,
    SUM(f.MontoTotalLinea) / COUNT(DISTINCT v.VendedorKey)               AS IngresoPromedioPorVendedor,
    SUM(f.MontoTotalLinea) / COUNT(DISTINCT f.VentaID)                   AS TicketPromedio
FROM dbo.vw_FactVentas AS f
INNER JOIN dbo.vw_DimVendedor AS v ON v.VendedorKey = f.VendedorKey
WHERE v.TipoVenta = N'Con Vendedor'
GROUP BY v.RangoAntiguedad
ORDER BY v.RangoAntiguedad;
GO
