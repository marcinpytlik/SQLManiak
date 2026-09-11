/*
    SQLLab CDC POC - Debezium login
    LAB ONLY: replace the password before execution.

    Existing CDC capture instances in this POC use @role_name = NULL,
    so no CDC gating role membership is required.
*/
USE [master];
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'debezium')
BEGIN
    CREATE LOGIN [debezium]
        WITH PASSWORD = N'ChangeMe_StrongPassword_2026!';
END
GO

USE [CDC_Lab];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'debezium')
BEGIN
    CREATE USER [debezium] FOR LOGIN [debezium];
END
GO

-- Snapshot: Debezium must be able to read the source tables.
GRANT SELECT ON OBJECT::dbo.Customer      TO [debezium];
GRANT SELECT ON OBJECT::dbo.CustomerOrder TO [debezium];
GO

-- CDC metadata and change objects used by the connector.
GRANT SELECT ON SCHEMA::cdc TO [debezium];
GO

-- Verification helpers used by the lab/runbook.
GRANT VIEW DATABASE STATE TO [debezium];
GO

PRINT 'Debezium login/user prepared for CDC_Lab.';
PRINT 'Remember to change the lab password and keep the same value outside Git, e.g. in DEBEZIUM_SQL_PASSWORD.';
GO
