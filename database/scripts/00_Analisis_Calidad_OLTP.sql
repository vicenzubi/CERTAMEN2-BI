SELECT 
    t.TABLE_NAME AS Tabla,
    c.COLUMN_NAME AS Columna,
    c.DATA_TYPE AS TipoDato,
    c.CHARACTER_MAXIMUM_LENGTH AS LargoMax,
    c.IS_NULLABLE AS AceptaNull
FROM INFORMATION_SCHEMA.TABLES t
INNER JOIN INFORMATION_SCHEMA.COLUMNS c 
    ON t.TABLE_NAME = c.TABLE_NAME
WHERE t.TABLE_TYPE = 'BASE TABLE'
  AND t.TABLE_NAME <> 'sysdiagrams'
ORDER BY t.TABLE_NAME, c.ORDINAL_POSITION;

SELECT 
    t.TerritorioID, 
    t.Territorio, 
    t.Grupo, 
    p.Pais,
    COUNT(a.AlmacenID) AS CantidadAlmacenes,
    STRING_AGG(a.Almacen, ', ') AS NombresAlmacenes
FROM Territorios t
LEFT JOIN Paises p ON t.PaisID = p.PaisID
LEFT JOIN Almacenes a ON t.TerritorioID = a.TerritorioID
GROUP BY t.TerritorioID, t.Territorio, t.Grupo, p.Pais;

SELECT 
    MIN(Fecha) AS FechaMinima, 
    MAX(Fecha) AS FechaMaxima,
    MIN(FechaEnvio) AS EnvioMinimo,
    MAX(FechaEnvio) AS EnvioMaximo,
    SUM(CASE WHEN FechaEnvio IS NULL THEN 1 ELSE 0 END) AS EnviosNulos,
    SUM(CASE WHEN VendedorID IS NULL THEN 1 ELSE 0 END) AS VendedoresNulos,
    SUM(CASE WHEN TerritorioID IS NULL THEN 1 ELSE 0 END) AS TerritoriosNulos
FROM Ventas;

SELECT 
    COUNT(*) AS TotalProductos,
    SUM(CASE WHEN Color IS NULL THEN 1 ELSE 0 END) AS ProductosSinColor,
    SUM(CASE WHEN CategoriaID IS NULL THEN 1 ELSE 0 END) AS ProductosSinCategoria
FROM Productos;