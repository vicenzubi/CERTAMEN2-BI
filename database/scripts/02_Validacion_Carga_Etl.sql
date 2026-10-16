SELECT 'Productos / DimProducto' AS Entidad,
       (SELECT COUNT(*) FROM BikeZ.dbo.Productos) AS Registros_OLTP,
       (SELECT COUNT(*) FROM DW_BikeZ.dbo.DimProducto) AS Registros_DW,
       'Debe cuadrar exacto (504)' AS Observacion
UNION ALL
SELECT 'Clientes / DimCliente',
       (SELECT COUNT(*) FROM BikeZ.dbo.Clientes),
       (SELECT COUNT(*) FROM DW_BikeZ.dbo.DimCliente),
       'Debe cuadrar exacto'
UNION ALL
SELECT 'Empleados / DimVendedor',
       (SELECT COUNT(*) FROM BikeZ.dbo.Empleados),
       (SELECT COUNT(*) FROM DW_BikeZ.dbo.DimVendedor),
       'DW tiene +1 por el registro Dummy (-1 Sin Vendedor)'
UNION ALL
SELECT 'Territorios / DimTerritorio',
       (SELECT COUNT(*) FROM BikeZ.dbo.Territorios),
       (SELECT COUNT(*) FROM DW_BikeZ.dbo.DimTerritorio),
       'Debe cuadrar exacto (10)';

SELECT 
    'Base Transaccional (OLTP)' AS Origen,
    COUNT(dv.DetalleVentaID) AS Total_Lineas_Venta,
    SUM(dv.Cantidad) AS Total_Unidades_Vendidas,
    CAST(SUM(dv.Cantidad * dv.PrecioUnitario) AS DECIMAL(18,2)) AS Monto_Total_Ingresos
FROM BikeZ.dbo.Ventas v
INNER JOIN BikeZ.dbo.DetalleVentas dv ON v.VentaID = dv.VentaID

UNION ALL

SELECT 
    'Data Warehouse (DW_BikeZ)' AS Origen,
    COUNT(FactVentaKey) AS Total_Lineas_Venta,
    SUM(Cantidad) AS Total_Unidades_Vendidas,
    SUM(MontoTotalLinea) AS Monto_Total_Ingresos
FROM DW_BikeZ.dbo.FactVentas;