/* TEST 09 - Operational readiness checks */
USE CDC_Lab;
GO

PRINT '=== CDC enabled ===';
SELECT name, is_cdc_enabled, recovery_model_desc, log_reuse_wait_desc
FROM sys.databases
WHERE name = N'CDC_Lab';
GO

PRINT '=== Tracked tables ===';
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    t.is_tracked_by_cdc
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE t.name IN (N'Customer', N'CustomerOrder');
GO

PRINT '=== Capture instances ===';
SELECT
    capture_instance,
    OBJECT_SCHEMA_NAME(source_object_id) AS source_schema,
    OBJECT_NAME(source_object_id) AS source_table,
    start_lsn,
    supports_net_changes,
    index_name,
    filegroup_name
FROM cdc.change_tables;
GO

PRINT '=== CDC jobs ===';
EXEC sys.sp_cdc_help_jobs;
GO

PRINT '=== Recent scan sessions ===';
SELECT TOP (20)
    session_id,
    start_time,
    end_time,
    duration,
    scan_phase,
    error_count,
    tran_count,
    command_count
FROM sys.dm_cdc_log_scan_sessions
ORDER BY session_id DESC;
GO

PRINT '=== Recent CDC errors ===';
SELECT TOP (20)
    entry_time,
    error_number,
    error_severity,
    error_state,
    error_message
FROM sys.dm_cdc_errors
ORDER BY entry_time DESC;
GO

PRINT '=== Available LSN range ===';
SELECT
    capture_instance,
    sys.fn_cdc_get_min_lsn(capture_instance) AS min_lsn,
    sys.fn_cdc_get_max_lsn() AS max_lsn
FROM cdc.change_tables;
GO

PRINT '=== Change table row counts ===';
SELECT 'cdc.dbo_Customer_CT' AS change_table, COUNT_BIG(*) AS rows_count
FROM cdc.dbo_Customer_CT
UNION ALL
SELECT 'cdc.dbo_CustomerOrder_CT', COUNT_BIG(*)
FROM cdc.dbo_CustomerOrder_CT;
GO

/*
After this SQL check, run:

cd .\scripts\CDC-POC\Debezium
.\03_Status.ps1
.\04_ListTopics.ps1

PASS:
- CDC enabled = 1
- tracked tables = 1
- capture and cleanup jobs present; capture is operational
- filegroup_name = CDC_CT for intended capture instances
- no new critical errors in sys.dm_cdc_errors
- connector/task = RUNNING
- expected Kafka topics exist
*/
