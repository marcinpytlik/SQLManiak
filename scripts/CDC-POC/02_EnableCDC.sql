/* SQLManiak - CDC POC | 02_EnableCDC.sql */
USE CDC_Lab;
GO

IF EXISTS (SELECT 1 FROM sys.databases WHERE database_id = DB_ID() AND is_cdc_enabled = 0)
    EXEC sys.sp_cdc_enable_db;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM cdc.change_tables AS ct
    WHERE ct.source_object_id = OBJECT_ID(N'dbo.Customer')
)
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = N'dbo',
        @source_name = N'Customer',
        @role_name = NULL,
        @filegroup_name = N'CDC_CT',
        @supports_net_changes = 1;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM cdc.change_tables AS ct
    WHERE ct.source_object_id = OBJECT_ID(N'dbo.CustomerOrder')
)
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = N'dbo',
        @source_name = N'CustomerOrder',
        @role_name = NULL,
        @filegroup_name = N'CDC_CT',
        @supports_net_changes = 1;
END;
GO

EXEC sys.sp_cdc_help_change_data_capture;
EXEC sys.sp_cdc_help_jobs;
GO

/* Verify that CDC change tables were created on the dedicated filegroup. */
SELECT
    OBJECT_SCHEMA_NAME(ct.source_object_id) AS source_schema,
    OBJECT_NAME(ct.source_object_id) AS source_table,
    ct.capture_instance,
    ct.filegroup_name,
    ct.supports_net_changes,
    ct.index_name
FROM cdc.change_tables AS ct
ORDER BY source_schema, source_table, capture_instance;
GO
