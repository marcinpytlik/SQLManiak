/*
    SQLLab CDC POC - Debezium login
    Intended to be executed by Stage2.ps1 / sqlcmd.
    Password is supplied as SQLCMD variable: DebeziumPassword.
*/
USE [master];
GO

IF N'$(DebeziumPassword)' = N'$(DebeziumPassword)'
BEGIN
    -- This branch is only reached when SQLCMD variable expansion did not happen.
    -- Kept as a readable guard for manual SSMS execution.
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'debezium')
BEGIN
    DECLARE @sql nvarchar(max) =
        N'CREATE LOGIN [debezium] WITH PASSWORD = ' + QUOTENAME(N'$(DebeziumPassword)', '''') + N';';
    EXEC sys.sp_executesql @sql;
END
ELSE
BEGIN
    DECLARE @alterSql nvarchar(max) =
        N'ALTER LOGIN [debezium] WITH PASSWORD = ' + QUOTENAME(N'$(DebeziumPassword)', '''') + N';';
    EXEC sys.sp_executesql @alterSql;
END
GO

USE [CDC_Lab];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'debezium')
BEGIN
    CREATE USER [debezium] FOR LOGIN [debezium];
END
GO

GRANT SELECT ON OBJECT::dbo.Customer      TO [debezium];
GRANT SELECT ON OBJECT::dbo.CustomerOrder TO [debezium];
GRANT SELECT ON SCHEMA::cdc TO [debezium];
GRANT VIEW DATABASE STATE TO [debezium];
GO

PRINT 'Debezium login/user prepared for CDC_Lab.';
GO
