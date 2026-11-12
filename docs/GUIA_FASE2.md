# Guía paso a paso · Fase 2 (Cubo OLAP + Dashboard + entrega final)

Esta guía explica **qué se construyó, por qué, y cómo replicarlo en tu computador** hasta dejar todo subido a GitHub y entregado. Sigue el orden de las secciones: cada una depende de la anterior.

| # | Sección | Tiempo estimado |
|---|---|---|
| 0 | [Qué se hizo y por qué](#0-qué-se-hizo-y-por-qué) | 10 min de lectura |
| 1 | [Preparar el repositorio y la rama](#1-preparar-el-repositorio-y-la-rama) | 5 min |
| 2 | [Capa analítica en SQL Server](#2-capa-analítica-en-sql-server) | 10 min |
| 3 | [Cubo OLAP en SSAS](#3-cubo-olap-en-ssas-visual-studio) | 60-90 min |
| 4 | [Dashboard en Power BI](#4-dashboard-en-power-bi) | 90-120 min |
| 5 | [Backup final de DW_BikeZ](#5-backup-final-de-dw_bikez) | 5 min |
| 6 | [Commits, push y Pull Requests](#6-commits-push-y-pull-requests) | 15 min |
| 7 | [Completar el informe Word](#7-completar-el-informe-word) | 30 min |
| 8 | [Presentación de 15 minutos](#8-guion-para-la-presentación-de-15-minutos) | — |
| 9 | [Solución de problemas](#9-solución-de-problemas-frecuentes) | — |

---

## 0. Qué se hizo y por qué

La Fase 1 dejó el Data Warehouse `DW_BikeZ` cargado y validado. La Fase 2 agrega las dos capas que pide el caso: **cubos OLAP (SSAS)** y **dashboard (Power BI)**, ambos ligados directamente a los 4 KPI.

```
BikeZ (OLTP) ──SSIS──> DW_BikeZ (estrella) ──vistas vw_*──┬──> Cubo OLAP SSAS (MDX + KPI)
                                                          └──> Power BI (DAX, 5 páginas)
```

### Decisiones clave (sirven para defender el proyecto)

1. **Vistas analíticas en vez de modificar tablas.** El modelo físico y el ETL ya estaban validados; tocarlos implicaba volver a cargar y validar. Las vistas (`03_Vistas_Analiticas.sql`) agregan atributos derivados sin cambiar el grano ni los datos. Las usan **el cubo y Power BI**, así ambos muestran exactamente lo mismo.
2. **KPI 2 por orden, no por línea.** `DiasDespacho` se repite en cada línea de una orden. Si se promedia por línea, una orden con 10 productos pesa 10 veces más. La vista marca la primera línea de cada orden (`EsPrimeraLineaOrden`) y deja los días sólo ahí (`DiasDespachoOrden`). Promedio = `SUM(DiasDespachoOrden) / SUM(EsPrimeraLineaOrden)`.
3. **Claves únicas por nivel de tiempo.** En SSAS, el miembro "Trimestre 1" no puede repetirse entre años. Por eso la vista crea `TrimestreKey = 20171` con nombre `T1 2017`, `MesKey = 201703` con nombre `Marzo 2017`, etc.
4. **Grupo de categoría.** Las 37 categorías se agrupan en Bicicletas, Componentes, Vestuario y Accesorios (+ "Sin Categoría") para tener una jerarquía Grupo > Categoría > Producto.
5. **Vendedor con nombre y rangos.** `Empleados` no tiene nombre, así que se crea `NombreVendedor` ("Vendedor 276 - Sales Representative"), `TipoVenta` (Venta Directa / Con Vendedor), antigüedad y rangos de antigüedad, horas de vacaciones y edad, todos calculados a la **última fecha de venta (31-07-2018)**.
6. **Power BI en modo Importar.** El profesor recibirá el `.pbix`; si estuviera conectado en vivo a tu SSAS local, al abrirlo en su computador no vería datos. Importando, el archivo es autocontenido. El cubo se valida con las mismas cifras.

### Hallazgos de datos que descubrí al analizar (úsenlos en la presentación)

* **Julio 2018 está incompleto:** sólo registra órdenes pequeñas (≈ $50 mil vs ≈ $3,6 millones en julio 2017). Por eso el crecimiento anual de 2018 sale negativo (-38,9 %) aunque el negocio crece. La comparación justa es **ene-jun 2018 vs ene-jun 2017 = +71,6 %**.
* **2015 sólo tiene julio-diciembre:** el +172 % de 2016 vs 2015 está inflado. El único año completo comparable es **2017 vs 2016 = +37,1 %**.
* **Despacho casi constante:** 30.995 de 31.465 órdenes (98,5 %) se despachan en exactamente 7 días. Las únicas excepciones están en la última semana de febrero de 2016 (8 días) y de 2018 (6 días): un efecto de calendario (año bisiesto) en el registro de fechas, no un problema logístico.

### Archivos nuevos en el repositorio

| Archivo | Para qué sirve |
|---|---|
| `database/scripts/03_Vistas_Analiticas.sql` | Crea las 6 vistas `vw_*` (base del cubo y del dashboard) |
| `database/scripts/04_Consultas_KPI.sql` | Calcula los KPI en SQL → valores esperados |
| `database/scripts/05_Permisos_SSAS.sql` | Da permiso de lectura al servicio de SSAS (sólo si falla el procesamiento) |
| `olap/proyecto-ssas/Calculos_Cubo_BikeZ.mdx` | Script de cálculos MDX que se pega en el cubo |
| `olap/proyecto-ssas/KPI_Cubo_BikeZ.md` | Definición de los 4 KPI del cubo (valor, meta, estado, tendencia) |
| `olap/proyecto-ssas/Consultas_Validacion_Cubo.mdx` | 11 consultas MDX con su resultado esperado |
| `powerbi/Medidas_DAX_BikeZ.dax` | Todas las medidas DAX del dashboard |
| `powerbi/Tema_BikeZ.json` | Tema de colores corporativo para Power BI |
| `docs/fase2/*.png` | Gráficos de resultados (van en el informe) |
| `docs/fase2/wireframes/*.png` | Diseño de cada página del dashboard |
| `docs/GUIA_FASE2.md` | Esta guía |
| `README.md` | Actualizado con la Fase 2 |

---

## 1. Preparar el repositorio y la rama

Abre **Git Bash** (o la terminal de VS Code) en la carpeta donde tienes clonado el repo:

```bash
cd ruta/a/CERTAMEN2-BI
git checkout main
git pull origin main                 # trae lo último que subió Vicente
git checkout -b feature/capa-analitica-olap
```

> Si aún no lo tienes clonado: `git clone https://github.com/vicenzubi/CERTAMEN2-BI.git` y luego `cd CERTAMEN2-BI`.

Descomprime `Fase2_archivos_repo.zip` **sobre la raíz del repositorio** (acepta reemplazar `README.md`). Verifica:

```bash
git status
```

Deberías ver como nuevos/modificados los archivos de la tabla anterior.

---

## 2. Capa analítica en SQL Server

1. Abre **SSMS** y conéctate a tu servidor (el mismo donde está `DW_BikeZ`).
2. Abre `database/scripts/03_Vistas_Analiticas.sql` y ejecútalo completo (**F5**).
3. Revisa la primera grilla de resultados. Debe decir exactamente:

| LineasVenta | UnidadesVendidas | MontoTotal | Ordenes | DiasPromedioDespacho | OrdenesDespachoTardio |
|---|---|---|---|---|---|
| 121317 | 274914 | 110373033.93 | 31465 | 6.99 | 58 |

4. Abre `04_Consultas_KPI.sql` y ejecútalo. **Toma un pantallazo** de algunas grillas (por ejemplo KPI 1 por año y KPI 4 por tipo de venta) para el informe. Estos son los números que deben dar el cubo y Power BI.

> **¿Error "Incorrect syntax near 'OR'" en `CREATE OR ALTER`?** Tu SQL Server es anterior a 2016 SP1. Cambia cada `CREATE OR ALTER VIEW` por `CREATE VIEW` (y si la vista ya existe, bórrala antes con `DROP VIEW`).

---

## 3. Cubo OLAP en SSAS (Visual Studio)

### 3.0 Requisitos

* **Analysis Services instalado en modo Multidimensional.** Compruébalo en SSMS: *Conectar > Analysis Services > Server name `localhost`*. Si conecta, haz clic derecho sobre el servidor > *Properties* > *General* y revisa **Server Mode = Multidimensional**. Si dice *Tabular* o no conecta, revisa la sección 9.
* Extensión **Microsoft Analysis Services Projects** en Visual Studio (*Extensiones > Administrar extensiones*). Es la misma familia que la extensión de Integration Services que ya usaron.

### 3.1 Crear el proyecto dentro de la solución existente

Así el profesor recibe **una sola solución** con el ETL y el cubo (lo que pide el enunciado).

1. Abre `etl/proyecto-ssis/ETL_BikeZ/ETL_BikeZ.sln`.
2. *Archivo > Agregar > Nuevo proyecto* → **Analysis Services Multidimensional Project**.
3. Nombre: `OLAP_BikeZ`. Ubicación: la carpeta `olap/proyecto-ssas` del repo. **Siguiente / Crear**.

### 3.2 Origen de datos (Data Source)

1. En el *Explorador de soluciones*, clic derecho en **Data Sources > New Data Source**.
2. *Create a data source based on an existing or new connection* → **New...**
   * Provider: **Native OLE DB\Microsoft OLE DB Driver for SQL Server** (o *SQL Server Native Client 11.0*).
   * Server name: tu servidor (ej. `localhost` o `.\SQLEXPRESS`), autenticación Windows.
   * Database: **DW_BikeZ** → *Test Connection* → OK.
3. Impersonation Information: **Use the service account**. (Si al procesar falla con *Login failed*, ejecuta `05_Permisos_SSAS.sql` o vuelve aquí y elige *Use a specific Windows user name and password* con tu usuario de Windows).
4. Nombre del data source: `DW BikeZ` → Finish.

### 3.3 Vista del origen de datos (Data Source View)

1. Clic derecho en **Data Source Views > New Data Source View** → elige `DW BikeZ`.
2. En *Select Tables and Views* pasa a la derecha **sólo las 6 vistas**: `vw_FactVentas`, `vw_DimTiempo`, `vw_DimProducto`, `vw_DimCliente`, `vw_DimVendedor`, `vw_DimTerritorio`. Nombre: `DSV BikeZ` → Finish.
3. **Claves lógicas** (las vistas no tienen PK): en el diagrama, para cada vista de dimensión haz clic derecho sobre su columna clave → **Set Logical Primary Key**:

| Vista | Columna clave |
|---|---|
| vw_DimTiempo | TiempoKey |
| vw_DimProducto | ProductoKey |
| vw_DimCliente | ClienteKey |
| vw_DimVendedor | VendedorKey |
| vw_DimTerritorio | TerritorioKey |
| vw_FactVentas | FactVentaKey |

4. **Relaciones** (6 en total): arrastra la columna de `vw_FactVentas` **hacia** la clave de la dimensión:

| Desde vw_FactVentas | Hacia |
|---|---|
| FechaPedidoKey | vw_DimTiempo.TiempoKey |
| FechaEnvioKey | vw_DimTiempo.TiempoKey |
| ProductoKey | vw_DimProducto.ProductoKey |
| ClienteKey | vw_DimCliente.ClienteKey |
| VendedorKey | vw_DimVendedor.VendedorKey |
| TerritorioKey | vw_DimTerritorio.TerritorioKey |

📸 **Captura para el informe:** el diagrama del DSV con las 6 relaciones.

### 3.4 Dimensiones

Para cada una: clic derecho en **Dimensions > New Dimension > Use an existing table**. Luego, dentro del editor de la dimensión, se renombran atributos (clic derecho > Rename o F2) y se ajustan propiedades en la ventana *Propiedades* (F4).

#### a) Dimensión `Tiempo`

1. Main table: `vw_DimTiempo` · Key columns: `TiempoKey` · Name column: `FechaNombre`.
2. Atributos a marcar: `Anio`, `Semestre Key`, `Trimestre Key`, `Mes Key`. Nombre de la dimensión: **Tiempo** → Finish.
3. Renombrar y configurar (seleccionar el atributo y F4):

| Atributo (nombre final) | KeyColumns | NameColumn | OrderBy |
|---|---|---|---|
| **Fecha** (era *Tiempo Key*) | TiempoKey | FechaNombre | Key |
| **Mes** (era *Mes Key*) | MesKey | MesNombre | Key |
| **Trimestre** (era *Trimestre Key*) | TrimestreKey | TrimestreNombre | Key |
| **Semestre** (era *Semestre Key*) | SemestreKey | SemestreNombre | Key |
| **Año** (era *Anio*) | Anio | AnioNombre | Key |

   Para NameColumn: clic en los `...` de la propiedad → elige la columna.

4. **Jerarquía:** arrastra desde el panel *Attributes* al panel *Hierarchies*, en este orden: Año, Semestre, Trimestre, Mes, Fecha. Renombra la jerarquía a **Calendario**.
5. Pestaña **Attribute Relationships**: deja la cadena `Fecha → Mes → Trimestre → Semestre → Año`. Si Fecha apunta directo a todos, arrastra Mes sobre Trimestre, Trimestre sobre Semestre y Semestre sobre Año, y borra las flechas directas sobrantes desde Fecha.
6. (Opcional, recomendado) En las propiedades de los atributos Semestre, Trimestre, Mes y Fecha pon **AttributeHierarchyVisible = False** para que sólo se navegue por la jerarquía.

#### b) Dimensión `Producto`

1. Main table: `vw_DimProducto` · Key: `ProductoKey` · Name column: `NombreProducto`.
2. Atributos: `Nombre Categoria`, `Grupo Categoria`, `Color`. Nombre: **Producto**.
3. Renombrar: *Producto Key* → **Producto**; *Nombre Categoria* → **Categoria**.
4. Jerarquía **Categorias**: Grupo Categoria > Categoria > Producto.
5. Attribute Relationships: `Producto → Categoria → Grupo Categoria` (y `Producto → Color`).

#### c) Dimensión `Cliente`

1. Main table: `vw_DimCliente` · Key: `ClienteKey` · Name column: `NombreCompleto`. Nombre: **Cliente**.
2. Renombrar *Cliente Key* → **Cliente**.

#### d) Dimensión `Vendedor`

1. Main table: `vw_DimVendedor` · Key: `VendedorKey` · Name column: `NombreVendedor`.
2. Atributos: `Tipo Venta`, `Cargo`, `Genero`, `Estado Civil`, `Rango Antiguedad`, `Rango Horas Vacaciones`, `Rango Edad`. Nombre: **Vendedor**.
3. Renombrar *Vendedor Key* → **Vendedor**.
4. Jerarquía **Fuerza de Ventas**: Tipo Venta > Cargo > Vendedor.
5. Attribute Relationships: `Vendedor → Cargo → Tipo Venta` (los demás atributos cuelgan de Vendedor).

#### e) Dimensión `Territorio`

1. Main table: `vw_DimTerritorio` · Key: `TerritorioKey` · Name column: `NombreTerritorio`.
2. Atributos: `Grupo`, `Nombre Pais`, `Cantidad Almacenes`. Nombre: **Territorio**.
3. Renombrar *Territorio Key* → **Territorio**; *Nombre Pais* → **Pais**.
4. Jerarquía **Geografia**: Grupo > Pais > Territorio.
5. Attribute Relationships: `Territorio → Pais → Grupo` (y `Territorio → Cantidad Almacenes`).

> ⚠️ Los nombres importan: el script MDX usa `[Fecha Pedido].[Calendario].[Año]`, `[Producto].[Categorias]`, `[Vendedor].[Fuerza de Ventas].[Tipo Venta]` y `[Territorio].[Geografia].[Pais]`.

📸 **Captura:** la estructura de la dimensión Tiempo (atributos + jerarquía Calendario).

### 3.5 Cubo

1. Clic derecho en **Cubes > New Cube > Use existing tables**.
2. Measure group tables: **vw_FactVentas**.
3. Medidas: deja marcadas **sólo** `Cantidad`, `Monto Total Linea`, `Dias Despacho`, `Es Primera Linea Orden`, `Dias Despacho Orden`, `Es Despacho Tardio` y `Vw Fact Ventas Count`. Desmarca claves, `Venta ID`, `Detalle Venta ID` y `Precio Unitario` (no es aditivo).
4. Existing dimensions: marca las 5. Si propone crear una dimensión nueva a partir de `vw_FactVentas`, **desmárcala**.
5. Nombre del cubo: **Cubo Ventas BikeZ** → Finish.

**Ajustar medidas** (pestaña *Cube Structure*, panel *Measures*; F4 para propiedades):

| Medida del asistente | Nuevo nombre | AggregateFunction | FormatString | Visible |
|---|---|---|---|---|
| Monto Total Linea | **Monto Ventas** | Sum | Currency | True |
| Cantidad | **Unidades Vendidas** | Sum | #,##0 | True |
| Vw Fact Ventas Count | **Lineas Venta** | Count | #,##0 | True |
| Es Primera Linea Orden | **Ordenes Base** | Sum | #,##0 | False |
| Dias Despacho Orden | **Dias Despacho Orden** | Sum | #,##0 | False |
| Es Despacho Tardio | **Ordenes Despacho Tardio** | Sum | #,##0 | True |
| Dias Despacho | **Dias Despacho Maximo** | **Max** | #,##0 | True |

* Renombra el grupo de medidas `Vw Fact Ventas` → **Ventas**.
* **Medida de órdenes (conteo distinto):** clic derecho en el grupo *Ventas* > **New Measure** → Usage: **Distinct count** → Source column: **VentaID** → OK. SSAS crea un grupo nuevo (ej. *Vw Fact Ventas 1*): renómbralo **Ordenes** y renombra la medida a **Ordenes** (FormatString `#,##0`).

**Dimension Usage** (pestaña):

* Verás la dimensión Tiempo dos veces (una por cada relación). Renómbralas (clic sobre el nombre de la columna/fila de la dimensión, F4 → *Name*) a **Fecha Pedido** y **Fecha Envio**. Revisa que *Fecha Pedido* use `Fecha Pedido Key` y *Fecha Envio* use `Fecha Envio Key`.
* Comprueba que el grupo **Ordenes** también esté relacionado (tipo *Regular*) con todas las dimensiones.

📸 **Captura:** la pestaña Dimension Usage y la pestaña Cube Structure.

### 3.6 Cálculos MDX

1. Pestaña **Calculations** → botón **Script View** (ícono de hoja con líneas en la barra de la pestaña).
2. Borra todo y pega el contenido de `olap/proyecto-ssas/Calculos_Cubo_BikeZ.mdx`. Guarda.
3. Vuelve a **Form View**: deben aparecer los miembros calculados agrupados en carpetas *KPI 1 - Crecimiento*, *KPI 2 - Despacho*, *KPI 3 - Catalogo* y *KPI 4 - Vendedores*.

| Miembro calculado | Qué calcula |
|---|---|
| Ingresos Periodo Anterior / Crecimiento vs Periodo Anterior | `PrevMember` en la jerarquía Calendario: mes vs mes anterior, año vs año anterior |
| Ingresos Año Anterior / Crecimiento Interanual | `ParallelPeriod` a nivel Año: mismo mes del año anterior |
| Tiempo Promedio Despacho / Tasa Despacho Tardio | Promedio por orden y % de órdenes con más de 7 días |
| Participacion Ingresos / Participacion Unidades / Precio Promedio Unitario | Participación de cada categoría sobre el total (`Root([Producto])`) |
| Ticket Promedio / Ticket Promedio Fuerza Ventas / Participacion Vendedor | Ingreso por orden y comparación con el promedio de la fuerza de ventas |

### 3.7 KPI del cubo

Pestaña **KPIs** → **New KPI** cuatro veces, copiando los campos de `olap/proyecto-ssas/KPI_Cubo_BikeZ.md`. Esto conecta el cubo **directamente** con los KPI del proyecto (valor, meta, estado y tendencia), que es lo que pide el enunciado.

### 3.8 Desplegar y procesar

1. Clic derecho en el proyecto `OLAP_BikeZ` > **Properties** > *Deployment*: **Server** = tu instancia de SSAS (ej. `localhost`), **Database** = `OLAP_BikeZ`.
2. Clic derecho en el proyecto > **Deploy**. Espera *Deploy Succeeded* y *Process Succeeded*.
3. Si falla, revisa la sección 9.

📸 **Captura:** la ventana de *Deployment Progress* con "Process Succeeded".

### 3.9 Navegar y validar

1. Pestaña **Browser** del cubo (botón *Reconnect* si está vacío). Arrastra `Monto Ventas`, `Crecimiento Interanual` y la jerarquía `Fecha Pedido > Calendario`.
2. Pestaña **KPIs** > **Browser View**: filtra `Fecha Pedido = 2017` y verás los 4 semáforos.
3. En SSMS: *Conectar > Analysis Services* → clic derecho en `OLAP_BikeZ` → *New Query > MDX*. Ejecuta, una a una, las consultas de `Consultas_Validacion_Cubo.mdx` y compara con el valor esperado que trae cada comentario.

📸 **Capturas para el informe:** Browser con ingresos por año y crecimiento; Browser de KPIs; resultado de la consulta Q1 (cuadratura).

---

## 4. Dashboard en Power BI

Abre los wireframes de `docs/fase2/wireframes/` (uno por página): muestran exactamente qué visual va en cada lugar y con qué campos.

### 4.1 Obtener datos

1. Power BI Desktop → **Obtener datos > SQL Server**.
2. Servidor: el tuyo · Base de datos: `DW_BikeZ` · Modo: **Importar** → Aceptar.
3. Marca **las 6 vistas** `vw_*` → **Transformar datos**.
4. En Power Query renombra cada consulta (doble clic en el nombre): `vw_FactVentas` → **FactVentas**, `vw_DimTiempo` → **DimTiempo**, `vw_DimProducto` → **DimProducto**, `vw_DimCliente` → **DimCliente**, `vw_DimVendedor` → **DimVendedor**, `vw_DimTerritorio` → **DimTerritorio**.
5. En `DimTiempo` verifica que la columna `Fecha` sea de tipo **Fecha** (ícono de calendario). → **Cerrar y aplicar**.

### 4.2 Modelo

1. **Vista de modelo** (tercer ícono a la izquierda). Power BI pudo crear relaciones automáticas: **bórralas todas** y crea las 6 correctas arrastrando la columna de la dimensión sobre la de FactVentas:

| Dimensión | → FactVentas | Estado |
|---|---|---|
| DimTiempo[TiempoKey] | FechaPedidoKey | **Activa** |
| DimTiempo[TiempoKey] | FechaEnvioKey | **Inactiva** (desmarca "Activar esta relación") |
| DimProducto[ProductoKey] | ProductoKey | Activa |
| DimCliente[ClienteKey] | ClienteKey | Activa |
| DimVendedor[VendedorKey] | VendedorKey | Activa |
| DimTerritorio[TerritorioKey] | TerritorioKey | Activa |

   Todas: cardinalidad *Varios a uno (*:1)*, dirección de filtro *Única*.
2. **Marcar tabla de fechas:** clic derecho en `DimTiempo` > *Marcar como tabla de fechas* > columna `Fecha`.
3. **Ordenar por columna** (vista de tabla, seleccionar columna > *Herramientas de columnas > Ordenar por columna*):
   * `MesNombre` ordenar por `MesKey`
   * `TrimestreNombre` por `TrimestreKey` · `SemestreNombre` por `SemestreKey` · `NombreMes` por `Mes`
4. **Ocultar** (clic derecho > *Ocultar en la vista de informe*) las columnas técnicas: todas las `...Key` de FactVentas, `EsPrimeraLineaOrden`, `DiasDespachoOrden`, `EsDespachoTardio`, `VentaID`, `DetalleVentaID`.
5. **Categoría de datos para el mapa:** `DimTerritorio[NombrePais]` → *Herramientas de columnas > Categoría de datos* = **País o región**.
6. 📸 **Captura:** vista de modelo (estrella).

### 4.3 Medidas DAX

1. *Inicio > Especificar datos* → nombre de tabla **Medidas** → *Cargar*.
2. Selecciona la tabla `Medidas` y, para cada medida de `powerbi/Medidas_DAX_BikeZ.dax`: *Nueva medida* → pega desde el nombre hasta el final de la fórmula → Enter.
3. Formatos (seleccionar la medida > *Herramientas de medidas*):
   * Moneda ($) con 0 decimales: Ingresos, Ingresos Mes Anterior, Ingresos Año Anterior, Ingresos Acumulados Año, Ticket Promedio, Ticket Promedio Fuerza Ventas, Ingresos Fuerza Ventas, Ingresos Venta Directa, Ingreso Promedio por Vendedor, Precio Promedio Unitario.
   * Porcentaje con 1 decimal: todas las que terminan en `%`.
   * Número entero con separador de miles: Unidades, Ordenes, Lineas Venta, Ordenes Despacho Tardio, Ordenes Despachadas.
   * Decimal con 2 decimales: Tiempo Promedio Despacho.
4. Borra la columna `Columna1` de la tabla Medidas (queda como tabla de medidas con ícono de calculadora).
5. **Validación rápida:** pon en una tarjeta `Ingresos` (debe decir 110.373.034), `Ordenes` (31.465), `Tiempo Promedio Despacho` (6,99) y `Ticket Promedio Fuerza Ventas` (21.281). Si alguna difiere, revisa las relaciones.

### 4.4 Tema y páginas

1. *Vista > Temas > Examinar temas* → `powerbi/Tema_BikeZ.json`.
2. Crea 5 páginas con los nombres y el contenido de los wireframes:

| Página | Usuario y pregunta que responde |
|---|---|
| **1 · Resumen Ejecutivo** | Dueño / gerencia: ¿cómo va el negocio en una sola mirada? |
| **2 · KPI 1 Crecimiento** | ¿Cuánto crecemos y en qué mercados? |
| **3 · KPI 2 Despacho** | ¿Cumplimos la promesa de 7 días? ¿Dónde hay demoras? |
| **4 · KPI 3 Catálogo** | ¿Qué categorías y productos sostienen los ingresos y el volumen? |
| **5 · KPI 4 Fuerza de ventas** | ¿Qué vendedores rinden más y qué factores se asocian a ello? |

Consejos de construcción:

* **Formato condicional por medida:** en un visual de barras, *Formato > Columnas/Barras > Color > fx* → *Estilo de formato: Valor del campo* → elige `Color Crecimiento`, `Color Despacho` o `Color Ticket`.
* **Línea de meta:** en un gráfico de columnas/líneas, panel *Análisis* (lupa) → *Línea constante* (7 días; 0,10 de crecimiento).
* **Top N:** panel *Filtros* del visual → `NombreProducto` → *Tipo de filtro: N superior* → 10 → *Por valor: Ingresos*.
* **Julio 2018 incompleto:** en el gráfico combinado de la página 2, agrega un filtro de visual `DimTiempo[MesKey] <= 201806` y un cuadro de texto pequeño: "Julio 2018 excluido: registros incompletos".
* **Medidor (página 3):** Valor `Tiempo Promedio Despacho`, Mínimo 0, Máximo 10, Destino `Meta Despacho Dias`.
* **Objeto KPI (página 2):** Valor `Ingresos`, Eje de tendencia `MesNombre`, Destino `Ingresos Año Anterior`.
* **Navegación:** en la página 1 inserta *Botones > Navegador > Navegador de páginas* para saltar entre páginas.
* **Interacciones:** con un visual seleccionado, *Formato > Editar interacciones* para decidir si filtra o resalta a los demás.

3. Guarda como `powerbi/Dashboard_BikeZ.pbix`.
4. 📸 **Captura de cada página** (pantalla completa, *Vista > Ajustar a la página*) para el informe.

---

## 5. Backup final de DW_BikeZ

El backup del repo es de la Fase 1 y **no contiene las vistas**. Hay que regenerarlo:

1. SSMS → clic derecho en `DW_BikeZ` > *Tareas > Copia de seguridad...*
2. Tipo: **Completa**. En *Destino* quita la ruta que aparezca y agrega `C:\...\CERTAMEN2-BI\database\backup\DW_BikeZ.bak` (o guárdalo en la carpeta por defecto y luego cópialo al repo).
3. Página *Opciones de medios*: **Sobrescribir todos los conjuntos de copia de seguridad existentes**. Aceptar.

> Si SQL Server no tiene permiso para escribir en tu carpeta del repo, guarda el `.bak` en la carpeta *Backup* por defecto de SQL Server y luego cópialo a mano.

(Opcional) Backup del cubo: SSMS conectado a Analysis Services → clic derecho en `OLAP_BikeZ` > *Back Up...* → `OLAP_BikeZ.abf`. No es obligatorio, porque el proyecto de Visual Studio permite volver a desplegarlo.

---

## 6. Commits, push y Pull Requests

Se mantiene el flujo de la Fase 1: ramas `feature/` + Pull Request a `main`. Se proponen **dos ramas** para que el historial quede ordenado.

### 6.1 Rama 1: capa analítica y cubo

```bash
# (ya estás en feature/capa-analitica-olap)
git add database/scripts/03_Vistas_Analiticas.sql database/scripts/04_Consultas_KPI.sql database/scripts/05_Permisos_SSAS.sql
git commit -m "Agrega vistas analiticas, consultas de KPI y permisos para SSAS"

git add olap/
git add etl/proyecto-ssis/ETL_BikeZ/ETL_BikeZ.sln     # la solución ahora incluye OLAP_BikeZ
git commit -m "Implementa cubo OLAP en SSAS con dimensiones, calculos MDX y KPI"

git push -u origin feature/capa-analitica-olap
```

En GitHub aparecerá el botón **Compare & pull request** → título *"Fase 2: capa analítica y cubo OLAP"* → **Create pull request**. Pide a Vicente que lo revise (o revísalo tú) y haz **Merge pull request**.

### 6.2 Rama 2: dashboard, backup y documentación

```bash
git checkout main
git pull origin main
git checkout -b feature/dashboard-powerbi

git add powerbi/
git commit -m "Agrega dashboard Power BI con medidas DAX y tema corporativo"

git add database/backup/DW_BikeZ.bak
git commit -m "Actualiza backup DW_BikeZ con vistas analiticas de la Fase 2"

git add docs/ README.md
git commit -m "Documenta Fase 2: cubo OLAP, dashboard, resultados y guia"

git push -u origin feature/dashboard-powerbi
```

Crea el Pull Request *"Fase 2: dashboard Power BI y documentación final"* y haz merge.

### 6.3 Comprobaciones antes de hacer push

* `git status` no debe mostrar carpetas `bin/`, `obj/` ni `.vs/` (ya están en `.gitignore`).
* El `.pbix` y el `.bak` pesan menos de 100 MB (límite de GitHub), así que se suben normalmente.
* Si `git push` responde **403 / Permission denied**, Vicente debe agregarte como colaborador (*Settings > Collaborators > Add people > OjedaDev*), o bien haz un *fork* y abre el Pull Request desde ahí.

---

## 7. Completar el informe Word

El archivo `Informe_Caso2_BikeZ_Final.docx` ya trae todo el texto de la Fase 1 y la Fase 2, con los resultados reales de los KPI y sus gráficos. Sólo falta:

1. **Reemplazar los recuadros amarillos** "[INSERTAR CAPTURA: ...]" por los pantallazos indicados (clic en el recuadro > borrar > *Insertar > Imágenes*). Cada recuadro dice exactamente qué captura va.
2. **Actualizar el índice:** clic derecho sobre el índice > *Actualizar campo* > *Actualizar toda la tabla* (deja los números de página correctos).
3. Revisar la tabla de **distribución de responsabilidades** de la Fase 2 y ajustarla a lo que realmente hizo cada uno.
4. Guardar y exportar a PDF si el portal lo requiere.

---

## 8. Guion para la presentación de 15 minutos

| Min | Contenido | Quién muestra |
|---|---|---|
| 0-1 | Problema de Bike Z y objetivo de la solución | — |
| 1-3 | Los 4 KPI y por qué se eligieron | Slides |
| 3-5 | Calidad de datos + modelo estrella (4 pasos de Kimball) | Diagrama |
| 5-7 | ETL en SSIS: flujo de control, nulos, dummy, idempotencia, cuadratura | Visual Studio |
| 7-9 | Capa analítica (vistas) y cubo OLAP: dimensiones, jerarquías, MDX, KPI en el *Browser* | Visual Studio / SSMS |
| 9-13 | Dashboard: recorrido por las 5 páginas con filtros en vivo | Power BI |
| 13-15 | Hallazgos y recomendaciones + cierre | Slides |

Preguntas probables del profesor (y respuesta corta):

* *¿Por qué el promedio de despacho no es AVG(DiasDespacho)?* → Porque se repite por línea; se calcula por orden con la primera línea de cada orden.
* *¿Por qué 2018 aparece con crecimiento negativo?* → Año incompleto y julio 2018 con registros incompletos; la comparación válida es ene-jun.
* *¿Qué es una dimensión de rol múltiple?* → La misma tabla Tiempo usada como Fecha Pedido y Fecha Envío.
* *¿Por qué Power BI no se conecta al cubo?* → Para que el `.pbix` sea autocontenido; ambos leen las mismas vistas y se validó que dan las mismas cifras.
* *¿Para qué está el registro dummy -1?* → Para no perder las 27.658 ventas directas (26,6 % de los ingresos).

---

## 9. Solución de problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| *Login failed for user 'NT Service\MSSQLServerOLAPService'* al procesar | El servicio SSAS no puede leer DW_BikeZ | Ejecutar `05_Permisos_SSAS.sql`, o en el Data Source usar *Use a specific Windows user name and password* |
| *A connection could not be made to the data source* / no encuentra el servidor SSAS al desplegar | Nombre de instancia distinto | Propiedades del proyecto > Deployment > Server (ej. `localhost\MSSQLSERVER` o el nombre que veas en SSMS) |
| *The server is in Tabular mode* / no aparece Analysis Services | SSAS no instalado o en modo Tabular | Ejecutar el instalador de SQL Server > *Agregar características* > Analysis Services > modo **Multidimensional** (crea una instancia nueva) |
| *Errors in the OLAP storage engine: A duplicate attribute key has been found* | Relación de atributos que no es 1 a 1 | Revisar Attribute Relationships: sólo las indicadas en 3.4. Como último recurso, en la dimensión: *Properties > ErrorConfiguration > (custom) > KeyDuplicate = IgnoreError* |
| El script MDX marca error en `[Fecha Pedido]` | La dimensión de cubo se llama distinto | Pestaña Dimension Usage: renombrar a `Fecha Pedido` y `Fecha Envio` |
| Error en `[Vendedor].[Fuerza de Ventas].[Tipo Venta].&[Con Vendedor]` | La jerarquía o el nivel tienen otro nombre | Revisar nombres en la dimensión Vendedor (jerarquía *Fuerza de Ventas*, nivel *Tipo Venta*) |
| Power BI: crecimiento interanual en blanco para 2016 | Es intencional: 2015 sólo tiene jul-dic | Se informa sólo desde 2017 (o por mes desde julio 2016) |
| Power BI: los meses salen en orden alfabético | Falta *Ordenar por columna* | `MesNombre` ordenar por `MesKey` |
| Power BI: totales duplicados o errores de "ambigüedad" | Relaciones automáticas mal creadas o dos relaciones activas a DimTiempo | Dejar sólo las 6 relaciones de 4.2, con FechaEnvio inactiva |
