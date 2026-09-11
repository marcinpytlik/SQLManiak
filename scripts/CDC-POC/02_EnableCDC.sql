/* SQLManiak - CDC POC | 02_EnableCDC.sql */
USE CDC_Lab;
GO

IF EXISTS (SELECT 1 FROM sys.databases WHERE database_id = DB_ID() AND is_cdc_enabled = 0)
    EXEC sys.sp_cdc_enable_db;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM cdc.change_tables ct
    WHERE ct.source_object_id = OBJECT_ID(N'dbo.Customer')
)
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = N'dbo',
        @source_name = N'Customer',
        @role_name = NULL,
        @supports_net_changes = 1;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM cdc.change_tables ct
    WHERE ct.source_object_id = OBJECT_ID(N'dbo.CustomerOrder')
)
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = N'dbo',
        @source_name = N'CustomerOrder',
        @role_name = NULL,
        @supports_net_changes = 1;
END;
GO

EXEC sys.sp_cdc_help_change_data_capture;
EXEC sys.sp_cdc_help_jobs;
GO
