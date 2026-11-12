/* ============================================================================
   CASO 2 - BIKE Z | FASE 2
   Script 05: Permiso de lectura para la cuenta de servicio de SSAS
   ----------------------------------------------------------------------------
   Cuándo usarlo:
     Si al PROCESAR el cubo en Visual Studio aparece un error del tipo
     "Login failed for user 'NT Service\MSSQLServerOLAPService'", significa que
     el servicio de Analysis Services no tiene permiso para leer DW_BikeZ.
   Nota:
     - Instancia por defecto de SSAS : NT Service\MSSQLServerOLAPService
     - Instancia con nombre (ej. TABULAR o SSAS): NT Service\MSOLAP$<NOMBRE>
       Reemplace el nombre en las dos líneas marcadas si corresponde.
   ============================================================================ */

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'NT Service\MSSQLServerOLAPService')
    CREATE LOGIN [NT Service\MSSQLServerOLAPService] FROM WINDOWS;          -- <-- nombre del servicio
GO

USE DW_BikeZ;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'NT Service\MSSQLServerOLAPService')
    CREATE USER [NT Service\MSSQLServerOLAPService] FOR LOGIN [NT Service\MSSQLServerOLAPService];  -- <-- idem
GO

ALTER ROLE db_datareader ADD MEMBER [NT Service\MSSQLServerOLAPService];
GO
