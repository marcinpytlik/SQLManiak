/*
    POC: Secure SSIS Export without unconstrained delegation
    Stage 1 - Create database
*/

USE [master];
GO

IF DB_ID(N'SSIS_Delegation_Lab') IS NULL
BEGIN
    PRINT 'Creating database SSIS_Delegation_Lab...';
    CREATE DATABASE [SSIS_Delegation_Lab];
END
ELSE
BEGIN
    PRINT 'Database SSIS_Delegation_Lab already exists.';
END;
GO

ALTER DATABASE [SSIS_Delegation_Lab] SET RECOVERY SIMPLE;
GO

ALTER DATABASE [SSIS_Delegation_Lab] SET PAGE_VERIFY CHECKSUM;
GO

USE [SSIS_Delegation_Lab];
GO

SELECT
    DB_NAME() AS DatabaseName,
    recovery_model_desc,
    page_verify_option_desc
FROM sys.databases
WHERE database_id = DB_ID();
GO
