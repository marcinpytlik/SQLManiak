/* SQLManiak - CDC POC | 05_CDC_Monitoring.sql */
USE CDC_Lab;
GO

-- Configuration and capture instances.
EXEC sys.sp_cdc_help_change_data_capture;
EXEC sys.sp_cdc_help_jobs;
GO

-- CDC jobs stored in msdb.
SELECT
    database_id,
    job_type,
    job_id,
    maxtrans,
    maxscans,
    continuous,
    pollinginterval,
    retention,
    threshold
FROM msdb.dbo.cdc_jobs
WHERE database_id = DB_ID(N'CDC_Lab');
GO

-- Recent scan sessions: errors, throughput and timing.
SELECT TOP (50)
    session_id,
    start_time,
    end_time,
    duration,
    scan_phase,
    error_count,
    tran_count,
    command_count,
    last_commit_lsn,
    last_commit_time
FROM sys.dm_cdc_log_scan_sessions
ORDER BY session_id DESC;
GO

-- Detailed CDC errors.
SELECT TOP (100)
    session_id,
    phase_number,
    entry_time,
    error_number,
    error_severity,
    error_state,
    error_message
FROM sys.dm_cdc_errors
ORDER BY entry_time DESC;
GO

-- Capture latency approximation: newest captured commit versus current time.
SELECT
    MAX(tran_end_time) AS LastCapturedCommitTime,
    DATEDIFF(SECOND, MAX(tran_end_time), SYSUTCDATETIME()) AS ApproxLatencySeconds
FROM cdc.lsn_time_mapping;
GO

-- Row counts in change tables.
SELECT
    OBJECT_SCHEMA_NAME(ct.object_id) AS ChangeTableSchema,
    OBJECT_NAME(ct.object_id) AS ChangeTableName,
    SUM(ps.row_count) AS RowCount
FROM cdc.change_tables AS ct
JOIN sys.dm_db_partition_stats AS ps
    ON ps.object_id = ct.object_id
   AND ps.index_id IN (0,1)
GROUP BY ct.object_id
ORDER BY RowCount DESC;
GO
