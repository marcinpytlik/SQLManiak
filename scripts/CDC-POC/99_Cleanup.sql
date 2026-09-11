/* SQLManiak - CDC POC | 99_Cleanup.sql */
USE CDC_Lab;
GO

IF EXISTS
(
    SELECT 1
    FROM cdc.change_tables
    WHERE source_object_id = OBJECT_ID(N'dbo.CustomerOrder')
)
BEGIN
    EXEC sys.sp_cdc_disable_table
        @source_schema = N'dbo',
        @source_name = N'CustomerOrder',
        @capture_instance = N'dbo_CustomerOrder';
END;
GO

IF EXISTS
(
    SELECT 1
    FROM cdc.change_tables
    WHERE source_object_id = OBJECT_ID(N'dbo.Customer')
)
BEGIN
    EXEC sys.sp_cdc_disable_table
        @source_schema = N'dbo',
        @source_name = N'Customer',
        @capture_instance = N'dbo_Customer';
END;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.databases
    WHERE database_id = DB_ID(N'CDC_Lab')
      AND is_cdc_enabled = 1
)
    EXEC sys.sp_cdc_disable_db;
GO

USE master;
GO

IF DB_ID(N'CDC_Lab') IS NOT NULL
BEGIN
    ALTER DATABASE CDC_Lab SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CDC_Lab;
END;
GO
