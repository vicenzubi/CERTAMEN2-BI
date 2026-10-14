USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'DW_BikeZ')
BEGIN
    CREATE DATABASE DW_BikeZ;
END
GO

USE DW_BikeZ;
GO

IF OBJECT_ID('dbo.FactVentas', 'U') IS NOT NULL DROP TABLE dbo.FactVentas;
IF OBJECT_ID('dbo.DimTiempo', 'U') IS NOT NULL DROP TABLE dbo.DimTiempo;
IF OBJECT_ID('dbo.DimProducto', 'U') IS NOT NULL DROP TABLE dbo.DimProducto;
IF OBJECT_ID('dbo.DimCliente', 'U') IS NOT NULL DROP TABLE dbo.DimCliente;
IF OBJECT_ID('dbo.DimVendedor', 'U') IS NOT NULL DROP TABLE dbo.DimVendedor;
IF OBJECT_ID('dbo.DimTerritorio', 'U') IS NOT NULL DROP TABLE dbo.DimTerritorio;
GO

CREATE TABLE dbo.DimTiempo (
    TiempoKey INT NOT NULL PRIMARY KEY,       
    Fecha DATE NOT NULL,
    Anio INT NOT NULL,
    Semestre INT NOT NULL,
    Trimestre INT NOT NULL,
    Mes INT NOT NULL,
    NombreMes NVARCHAR(20) NOT NULL,
    Dia INT NOT NULL,
    NombreDia NVARCHAR(20) NOT NULL
);
GO

CREATE TABLE dbo.DimProducto (
    ProductoKey INT IDENTITY(1,1) NOT NULL PRIMARY KEY, 
    ProductoID INT NOT NULL,                            
    NombreProducto NVARCHAR(150) NOT NULL,
    Color NVARCHAR(50) NOT NULL,                        
    CategoriaID INT NOT NULL,                           
    NombreCategoria NVARCHAR(100) NOT NULL              
);
GO

CREATE TABLE dbo.DimCliente (
    ClienteKey INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  
    ClienteID INT NOT NULL,                             
    Nombre NVARCHAR(100) NOT NULL,
    Apellido NVARCHAR(100) NOT NULL,
    NombreCompleto NVARCHAR(205) NOT NULL               
);
GO

CREATE TABLE dbo.DimVendedor (
    VendedorKey INT IDENTITY(1,1) NOT NULL PRIMARY KEY, 
    EmpleadoID INT NOT NULL,                           
    Cargo NVARCHAR(100) NOT NULL,
    FechaNacimiento DATE NULL,
    EstadoCivil NVARCHAR(20) NOT NULL,
    Genero NVARCHAR(20) NOT NULL,
    FechaContratacion DATE NULL,
    HorasVacaciones INT NOT NULL
);
GO

CREATE TABLE dbo.DimTerritorio (
    TerritorioKey INT IDENTITY(1,1) NOT NULL PRIMARY KEY, 
    TerritorioID INT NOT NULL,                            
    NombreTerritorio NVARCHAR(100) NOT NULL,
    Grupo NVARCHAR(100) NOT NULL,
    PaisID NVARCHAR(10) NOT NULL,
    NombrePais NVARCHAR(100) NOT NULL,
    CantidadAlmacenes INT NOT NULL                       
);
GO

CREATE TABLE dbo.FactVentas (
    FactVentaKey INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ProductoKey INT NOT NULL,
    ClienteKey INT NOT NULL,
    VendedorKey INT NOT NULL,
    TerritorioKey INT NOT NULL,
    FechaPedidoKey INT NOT NULL,
    FechaEnvioKey INT NOT NULL,
    VentaID INT NOT NULL,
    DetalleVentaID INT NOT NULL,
    Cantidad INT NOT NULL,
    PrecioUnitario DECIMAL(18,2) NOT NULL,
    MontoTotalLinea DECIMAL(18,2) NOT NULL,
    DiasDespacho INT NOT NULL,

    CONSTRAINT FK_FactVentas_DimProducto FOREIGN KEY (ProductoKey) REFERENCES dbo.DimProducto(ProductoKey),
    CONSTRAINT FK_FactVentas_DimCliente FOREIGN KEY (ClienteKey) REFERENCES dbo.DimCliente(ClienteKey),
    CONSTRAINT FK_FactVentas_DimVendedor FOREIGN KEY (VendedorKey) REFERENCES dbo.DimVendedor(VendedorKey),
    CONSTRAINT FK_FactVentas_DimTerritorio FOREIGN KEY (TerritorioKey) REFERENCES dbo.DimTerritorio(TerritorioKey),
    CONSTRAINT FK_FactVentas_FechaPedido FOREIGN KEY (FechaPedidoKey) REFERENCES dbo.DimTiempo(TiempoKey),
    CONSTRAINT FK_FactVentas_FechaEnvio FOREIGN KEY (FechaEnvioKey) REFERENCES dbo.DimTiempo(TiempoKey)
);
GO

INSERT INTO dbo.DimVendedor (EmpleadoID, Cargo, FechaNacimiento, EstadoCivil, Genero, FechaContratacion, HorasVacaciones)
VALUES (-1, N'Sin Vendedor (Venta Directa)', '1900-01-01', N'N/A', N'N/A', '1900-01-01', 0);
GO

SET LANGUAGE Spanish;

WITH FechasCTE AS (
    SELECT CAST('2015-01-01' AS DATE) AS FechaValor
    UNION ALL
    SELECT DATEADD(DAY, 1, FechaValor)
    FROM FechasCTE
    WHERE FechaValor < '2018-12-31'
)
INSERT INTO dbo.DimTiempo (TiempoKey, Fecha, Anio, Semestre, Trimestre, Mes, NombreMes, Dia, NombreDia)
SELECT 
    CAST(FORMAT(FechaValor, 'yyyyMMdd') AS INT) AS TiempoKey,
    FechaValor AS Fecha,
    YEAR(FechaValor) AS Anio,
    CASE WHEN MONTH(FechaValor) <= 6 THEN 1 ELSE 2 END AS Semestre,
    DATEPART(QUARTER, FechaValor) AS Trimestre,
    MONTH(FechaValor) AS Mes,
    UPPER(LEFT(DATENAME(MONTH, FechaValor), 1)) + LOWER(SUBSTRING(DATENAME(MONTH, FechaValor), 2, 20)) AS NombreMes,
    DAY(FechaValor) AS Dia,
    UPPER(LEFT(DATENAME(WEEKDAY, FechaValor), 1)) + LOWER(SUBSTRING(DATENAME(WEEKDAY, FechaValor), 2, 20)) AS NombreDia
FROM FechasCTE
OPTION (MAXRECURSION 0);
GO