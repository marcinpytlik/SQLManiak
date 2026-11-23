/*
 SQLManiak | Database Incident Diagnostics v1.0
 SQL Server 2016 / 2019 / 2022 | FCI compatible
 READ ONLY: no KILL, DBCC, ALTER, backup, restore, shrink or failover.

 HOW TO USE
  1. Connect directly to the SQL Server instance as sysadmin (preferably to master).
  2. Change @DatabaseName below and optionally @HoursBack.
  3. Execute entire script in SSMS (Results to Grid).
  4. Review result sets by SECTION, particularly DATABASE, REQUESTS, BLOCKING,
     SESSIONS, IO, BACKUPS and ERRORLOG.

 NOTE: Snapshot of dynamic DMVs shows CURRENT activity only.
       Historical evidence depends on msdb / ERRORLOG / optional Query Store.
*/
USE master;
SET NOCOUNT ON;
SET LOCK_TIMEOUT 5000;
SET DEADLOCK_PRIORITY LOW;

DECLARE @DatabaseName sysname = N'TwojaBaza';  -- << CHANGE
DECLARE @HoursBack int = 24;                  -- error log / backup lookback
DECLARE @IncludeErrorLog bit = 1;             -- xp_readerrorlog (may take time)
DECLARE @IncludeFileUsage bit = 1;            -- FILEPROPERTY in target DB
DECLARE @IncludeQueryStore bit = 0;           -- optional (may be expensive)

IF @HoursBack < 1 OR @HoursBack > 168 SET @HoursBack = 24;
DECLARE @DatabaseId int = DB_ID(@DatabaseName);
DECLARE @Since datetime = DATEADD(HOUR, -@HoursBack, GETDATE());
DECLARE @Now datetime = GETDATE();
DECLARE @Sql nvarchar(max);

SELECT N'00_CONTEXT' AS Section,
       @@SERVERNAME AS ServerName,
       SERVERPROPERTY('MachineName') AS MachineName,
       SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS CurrentNode,
       SERVERPROPERTY('InstanceName') AS InstanceName,
       SERVERPROPERTY('ProductVersion') AS ProductVersion,
       SYSDATETIMEOFFSET() AS CollectedAt,
       @DatabaseName AS TargetDatabase,
       @DatabaseId AS TargetDatabaseId,
       @Since AS HistoryFromLocalTime;

IF @DatabaseId IS NULL
BEGIN
    SELECT N'ERROR' AS Section,
           N'Database not found or its metadata is not visible on this instance. Verify name and server.' AS Message;
    RETURN;
END;

SELECT N'01_DATABASE_STATE' AS Section,
       d.name, d.state_desc, d.user_access_desc,
       d.is_read_only, d.is_auto_close_on,
       d.recovery_model_desc, d.is_in_standby,
       d.log_reuse_wait_desc,
       HAS_DBACCESS(d.name) AS HasDbAccess,
       d.create_date
FROM sys.databases AS d
WHERE d.database_id = @DatabaseId;

SELECT N'02_DATABASE_FILES' AS Section,
       mf.name AS LogicalFileName, mf.type_desc,
       mf.state_desc AS FileState,
       mf.physical_name,
       CAST(mf.size / 128.0 AS decimal(19,2)) AS FileSizeMB,
       CASE WHEN mf.max_size = -1 THEN N'UNLIMITED'
            WHEN mf.max_size = 0 THEN N'NO_GROWTH'
            ELSE CONVERT(nvarchar(30), CAST(mf.max_size / 128.0 AS decimal(19,2))) END AS MaxSizeMB,
       mf.growth AS RawGrowth,
       mf.is_percent_growth
FROM sys.master_files AS mf
WHERE mf.database_id = @DatabaseId
ORDER BY mf.file_id;

IF @IncludeFileUsage = 1
BEGIN
    IF EXISTS (SELECT 1 FROM sys.databases WHERE database_id = @DatabaseId AND state = 0)
       AND HAS_DBACCESS(@DatabaseName) = 1
    BEGIN
        BEGIN TRY
            SET @Sql = N'USE ' + QUOTENAME(@DatabaseName) + N';
            SELECT N''03_FILE_USAGE_DATA_ONLY'' AS Section,
                   name AS LogicalFileName, type_desc,
                   CAST(size/128.0 AS decimal(19,2)) AS SizeMB,
                   CAST(FILEPROPERTY(name, ''SpaceUsed'')/128.0 AS decimal(19,2)) AS UsedMB,
                   CAST((size-FILEPROPERTY(name, ''SpaceUsed''))/128.0 AS decimal(19,2)) AS FreeMB
            FROM sys.database_files WHERE type = 0;';
            EXEC sys.sp_executesql @Sql;
        END TRY
        BEGIN CATCH
            SELECT N'03_FILE_USAGE_WARNING' AS Section, ERROR_NUMBER() AS ErrorNumber,
                   ERROR_MESSAGE() AS Message;
        END CATCH;
    END
    ELSE
        SELECT N'03_FILE_USAGE_SKIPPED' AS Section,
               N'Database not ONLINE or access not available.' AS Message;
END;

SELECT N'04_ACTIVE_REQUESTS' AS Section,
       r.session_id, s.login_name, s.host_name, s.program_name,
       DB_NAME(r.database_id) AS RequestDatabase,
       r.command, r.status, r.blocking_session_id,
       r.wait_type, r.wait_time AS WaitMs,
       r.total_elapsed_time AS ElapsedMs, r.cpu_time AS CpuMs,
       r.logical_reads, r.reads, r.writes,
       r.percent_complete, r.start_time,
       SUBSTRING(st.text,
           (r.statement_start_offset/2)+1,
           ((CASE WHEN r.statement_end_offset = -1 THEN DATALENGTH(st.text)
                  ELSE r.statement_end_offset END - r.statement_start_offset)/2)+1
       ) AS CurrentStatement,
       st.text AS BatchText
FROM sys.dm_exec_requests AS r
JOIN sys.dm_exec_sessions AS s ON r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
WHERE r.session_id <> @@SPID
  AND (r.database_id = @DatabaseId
       OR r.blocking_session_id IN
           (SELECT request_session_id
            FROM sys.dm_tran_locks
            WHERE resource_database_id = @DatabaseId))
ORDER BY r.total_elapsed_time DESC;

-- Root blockers can be sleeping, and may have a current database other than target.
;WITH waiting AS
(
    SELECT session_id, blocking_session_id, wait_type, wait_time
    FROM sys.dm_exec_requests
    WHERE blocking_session_id > 0
      AND (database_id = @DatabaseId
           OR session_id IN
              (SELECT request_session_id FROM sys.dm_tran_locks
               WHERE resource_database_id = @DatabaseId))
)
SELECT N'05_BLOCKING_CHAINS' AS Section,
       w.session_id AS BlockedSessionId,
       w.blocking_session_id AS BlockingSessionId,
       w.wait_type, w.wait_time AS WaitMs,
       bs.status AS BlockerSessionStatus,
       bs.login_name AS BlockerLogin,
       bs.host_name AS BlockerHost,
       bs.program_name AS BlockerProgram,
       br.command AS BlockerCommand,
       txt.text AS BlockerLastBatch
FROM waiting AS w
LEFT JOIN sys.dm_exec_sessions AS bs ON bs.session_id = w.blocking_session_id
LEFT JOIN sys.dm_exec_requests AS br ON br.session_id = w.blocking_session_id
LEFT JOIN sys.dm_exec_connections AS bc ON bc.session_id = w.blocking_session_id
OUTER APPLY sys.dm_exec_sql_text(COALESCE(br.sql_handle, bc.most_recent_sql_handle)) AS txt
ORDER BY w.wait_time DESC;

SELECT N'06_SESSIONS_WITH_DB_LOCKS' AS Section,
       l.request_session_id AS SessionId,
       s.status AS SessionStatus,
       s.login_name, s.host_name, s.program_name,
       s.open_transaction_count, s.last_request_start_time,
       s.last_request_end_time,
       COUNT_BIG(*) AS LockCount,
       SUM(CASE WHEN l.request_status = 'WAIT' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS WaitingLockCount
FROM sys.dm_tran_locks AS l
LEFT JOIN sys.dm_exec_sessions AS s ON s.session_id = l.request_session_id
WHERE l.resource_database_id = @DatabaseId
  AND l.request_session_id > 0
GROUP BY l.request_session_id, s.status, s.login_name, s.host_name,
         s.program_name, s.open_transaction_count,
         s.last_request_start_time, s.last_request_end_time
ORDER BY WaitingLockCount DESC, LockCount DESC;

SELECT N'07_WAITING_LOCKS' AS Section,
       l.request_session_id, l.resource_type, l.request_mode,
       l.request_status, l.resource_description,
       l.request_owner_type
FROM sys.dm_tran_locks AS l
WHERE l.resource_database_id = @DatabaseId
  AND l.request_status = 'WAIT'
ORDER BY l.request_session_id;

SELECT N'08_DATABASE_TRANSACTIONS' AS Section,
       st.session_id, s.status AS SessionStatus,
       s.login_name, s.host_name, s.program_name,
       at.transaction_begin_time, at.name AS TransactionName,
       at.transaction_state, dt.database_transaction_log_bytes_used,
       dt.database_transaction_log_bytes_reserved
FROM sys.dm_tran_database_transactions AS dt
JOIN sys.dm_tran_active_transactions AS at
  ON dt.transaction_id = at.transaction_id
LEFT JOIN sys.dm_tran_session_transactions AS st
  ON dt.transaction_id = st.transaction_id
LEFT JOIN sys.dm_exec_sessions AS s
  ON st.session_id = s.session_id
WHERE dt.database_id = @DatabaseId
ORDER BY at.transaction_begin_time;

SELECT N'09_IO_STATS_CUMULATIVE' AS Section,
       mf.name AS LogicalFileName,
       vfs.file_id,
       vfs.num_of_reads, vfs.num_of_writes,
       CAST(vfs.io_stall_read_ms * 1.0 / NULLIF(vfs.num_of_reads,0) AS decimal(19,2)) AS AvgReadLatencyMs,
       CAST(vfs.io_stall_write_ms * 1.0 / NULLIF(vfs.num_of_writes,0) AS decimal(19,2)) AS AvgWriteLatencyMs,
       CAST(vfs.num_of_bytes_read / 1048576.0 AS decimal(19,2)) AS MBRead,
       CAST(vfs.num_of_bytes_written / 1048576.0 AS decimal(19,2)) AS MBWritten
FROM sys.dm_io_virtual_file_stats(@DatabaseId, NULL) AS vfs
JOIN sys.master_files AS mf
  ON mf.database_id = vfs.database_id AND mf.file_id = vfs.file_id
ORDER BY mf.file_id;

SELECT N'10_RECENT_BACKUPS' AS Section,
       TOP_BACKUP.backup_start_date, TOP_BACKUP.backup_finish_date,
       TOP_BACKUP.type AS BackupType_D_F_I_L,
       TOP_BACKUP.is_copy_only,
       TOP_BACKUP.backup_size / 1048576.0 AS BackupSizeMB,
       TOP_BACKUP.compressed_backup_size / 1048576.0 AS CompressedSizeMB,
       TOP_BACKUP.server_name, TOP_BACKUP.machine_name
FROM
(
    SELECT TOP (30) b.*
    FROM msdb.dbo.backupset AS b
    WHERE b.database_name = @DatabaseName
      AND b.backup_start_date >= @Since
    ORDER BY b.backup_start_date DESC
) AS TOP_BACKUP
ORDER BY TOP_BACKUP.backup_start_date DESC;

SELECT N'11_RECENT_FAILED_AGENT_STEPS' AS Section,
       j.name AS JobName, h.step_id, h.step_name,
       msdb.dbo.agent_datetime(h.run_date,h.run_time) AS ExecutionTime,
       h.sql_message_id, h.sql_severity,
       h.message
FROM msdb.dbo.sysjobhistory AS h
JOIN msdb.dbo.sysjobs AS j ON j.job_id = h.job_id
WHERE h.run_status = 0
  AND h.step_id > 0
  AND h.run_date >= CONVERT(int, CONVERT(char(8), @Since, 112))
ORDER BY h.instance_id DESC;

IF @IncludeErrorLog = 1
BEGIN
    -- Read SQL ERRORLOG, not the Windows Event Log; 0 = current log.
    -- Log records may be rotated; historical logs are not scanned here.
    BEGIN TRY
        SELECT N'12_ERRORLOG_BACKUP_3041' AS Section,
               N'Following result set contains current SQL ERRORLOG lines matching 3041.' AS Message;
        EXEC sys.xp_readerrorlog 0, 1, N'3041', NULL,
                                  @Since, @Now, N'desc';
    END TRY
    BEGIN CATCH
        SELECT N'12_ERRORLOG_WARNING' AS Section,
               ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS Message;
    END CATCH;
    BEGIN TRY
        SELECT N'13_ERRORLOG_DATABASE_NAME' AS Section,
               N'Following result set contains current SQL ERRORLOG lines matching target database name.' AS Message;
        EXEC sys.xp_readerrorlog 0, 1, @DatabaseName, NULL,
                                  @Since, @Now, N'desc';
    END TRY
    BEGIN CATCH
        SELECT N'13_ERRORLOG_WARNING' AS Section,
               ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS Message;
    END CATCH;
END;

IF @IncludeQueryStore = 1
BEGIN
    IF EXISTS (SELECT 1 FROM sys.databases
               WHERE database_id = @DatabaseId AND state = 0)
       AND HAS_DBACCESS(@DatabaseName) = 1
    BEGIN
        BEGIN TRY
            SET @Sql = N'USE ' + QUOTENAME(@DatabaseName) + N';
            IF EXISTS (SELECT 1 FROM sys.database_query_store_options
                       WHERE actual_state_desc IN (''READ_WRITE'', ''READ_ONLY''))
            BEGIN
                SELECT TOP (20)
                    N''14_QUERY_STORE_HIGH_DURATION'' AS Section,
                    q.query_id, p.plan_id,
                    SUM(rs.count_executions) AS Executions,
                    CAST(SUM(rs.avg_duration * rs.count_executions)
                         / NULLIF(SUM(rs.count_executions),0) / 1000.0 AS decimal(19,2)) AS WeightedAvgDurationMs,
                    CAST(MAX(rs.max_duration) / 1000.0 AS decimal(19,2)) AS MaxDurationMs,
                    MAX(i.end_time) AS LastIntervalEndUtcOffset,
                    qt.query_sql_text
                FROM sys.query_store_runtime_stats AS rs
                JOIN sys.query_store_runtime_stats_interval AS i
                     ON i.runtime_stats_interval_id = rs.runtime_stats_interval_id
                JOIN sys.query_store_plan AS p ON p.plan_id = rs.plan_id
                JOIN sys.query_store_query AS q ON q.query_id = p.query_id
                JOIN sys.query_store_query_text AS qt ON qt.query_text_id = q.query_text_id
                WHERE i.end_time >= DATEADD(HOUR, -@HoursBack, SYSDATETIMEOFFSET())
                GROUP BY q.query_id, p.plan_id, qt.query_sql_text
                ORDER BY MaxDurationMs DESC;
            END
            ELSE SELECT N''14_QUERY_STORE_SKIPPED'' AS Section,
                        N''Query Store is disabled or unavailable.'' AS Message;';
            EXEC sys.sp_executesql @Sql, N'@HoursBack int', @HoursBack = @HoursBack;
        END TRY
        BEGIN CATCH
            SELECT N'14_QUERY_STORE_WARNING' AS Section,
                   ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS Message;
        END CATCH;
    END
END;

SELECT N'99_FINISHED' AS Section,
       SYSDATETIMEOFFSET() AS FinishedAt,
       N'Read-only diagnostics complete. msdb backups show successful backup records, not necessarily all failed attempts; use ERRORLOG and Agent history for failures.' AS Reminder;
