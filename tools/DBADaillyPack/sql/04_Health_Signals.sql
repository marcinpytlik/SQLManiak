/* Quick health signals: CPU runnable, memory grants pending, top active requests */
SET NOCOUNT ON;

-- Scheduler / runnable tasks (CPU pressure indicator)
SELECT
    scheduler_id,
    current_tasks_count,
    runnable_tasks_count,
    active_workers_count,
    load_factor
FROM sys.dm_os_schedulers
WHERE status = 'VISIBLE ONLINE'
ORDER BY runnable_tasks_count DESC;

PRINT '---';

-- Memory grants pending (query memory pressure)
SELECT
    (SELECT COUNT(*) FROM sys.dm_exec_query_memory_grants WHERE grant_time IS NULL) AS MemoryGrantsPending,
    (SELECT COUNT(*) FROM sys.dm_exec_query_memory_grants) AS MemoryGrantsTotal;

PRINT '---';

-- Top active requests (duration)
SELECT TOP (25)
    r.session_id,
    r.status,
    r.command,
    r.cpu_time,
    r.total_elapsed_time,
    r.reads,
    r.writes,
    r.logical_reads,
    DB_NAME(r.database_id) AS DatabaseName,
    r.wait_type,
    r.wait_time,
    r.blocking_session_id,
    SUBSTRING(t.text, (r.statement_start_offset/2)+1,
        CASE WHEN r.statement_end_offset = -1
             THEN (DATALENGTH(t.text) - r.statement_start_offset)/2 + 1
             ELSE (r.statement_end_offset - r.statement_start_offset)/2 + 1
        END) AS StatementText
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id <> @@SPID
ORDER BY r.total_elapsed_time DESC;
