USE [master];
GO

-- sprzątanie po poprzednich uruchomieniach, jeśli istnieją
/*
USE [master];
GO
ALTER DATABASE [StockFlowDb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO



DROP DATABASE [StockFlowDb];
GO

EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'StockFlowDb';
GO

DROP LOGIN [stockflow_deploy];
GO

DROP LOGIN [stockflow_runtime];
GO
*/

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'stockflow_deploy')
BEGIN
    CREATE LOGIN [stockflow_deploy]
    WITH PASSWORD = 'UseVeryStrongPassword_Deploy_Only!';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'stockflow_runtime')
BEGIN
    CREATE LOGIN [stockflow_runtime]
    WITH PASSWORD = 'UseVeryStrongPassword_Runtime_Only!';
END
GO

IF DB_ID(N'StockFlowDb') IS NULL
BEGIN
    CREATE DATABASE [StockFlowDb];
END
GO

USE [StockFlowDb];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'stockflow_deploy')
BEGIN
    CREATE USER [stockflow_deploy] FOR LOGIN [stockflow_deploy];
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'stockflow_runtime')
BEGIN
    CREATE USER [stockflow_runtime] FOR LOGIN [stockflow_runtime];
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'app')
BEGIN
    EXEC('CREATE SCHEMA [app] AUTHORIZATION [dbo]');
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'api')
BEGIN
    EXEC('CREATE SCHEMA [api] AUTHORIZATION [dbo]');
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'stockflow_deploy_role' AND type = 'R')
BEGIN
    CREATE ROLE [stockflow_deploy_role];
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'stockflow_runtime_role' AND type = 'R')
BEGIN
    CREATE ROLE [stockflow_runtime_role];
END
GO

BEGIN TRY
    ALTER ROLE [stockflow_deploy_role] ADD MEMBER [stockflow_deploy];
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (15023, 15151, 15247)
        THROW;
END CATCH;
GO

BEGIN TRY
    ALTER ROLE [stockflow_runtime_role] ADD MEMBER [stockflow_runtime];
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (15023, 15151, 15247)
        THROW;
END CATCH;
GO

/* =========================================================
   UPRAWNIENIA DLA DEPLOYMENT
   ========================================================= */

GRANT CREATE TABLE TO [stockflow_deploy_role];
GRANT CREATE VIEW TO [stockflow_deploy_role];
GRANT CREATE PROCEDURE TO [stockflow_deploy_role];
GRANT CREATE FUNCTION TO [stockflow_deploy_role];

GRANT ALTER ON SCHEMA::[app] TO [stockflow_deploy_role];
GRANT ALTER ON SCHEMA::[api] TO [stockflow_deploy_role];
GO


GRANT SELECT, INSERT, UPDATE, DELETE
ON SCHEMA::[app]
TO [stockflow_deploy_role];
GO

/* =========================================================
   UPRAWNIENIA DLA RUNTIME
   ========================================================= */

GRANT SELECT, INSERT, UPDATE, DELETE
ON SCHEMA::[app]
TO [stockflow_runtime_role];
GO