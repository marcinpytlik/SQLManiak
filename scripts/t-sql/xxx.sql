DECLARE @spid int = 57; -- ← Twój SPID

-- Sesja + bieżące żądanie
SELECT
  s.session_id,
  s.login_name, s.host_name, s.program_name, s.database_id,
  s.status AS session_status, s.open_transaction_count,
  r.status AS request_status, r.command, r.cpu_time, r.total_elapsed_time,
  r.reads, r.writes, r.logical_reads,
  r.wait_type, r.wait_time, r.wait_resource, r.blocking_session_id,
  r.percent_complete
FROM sys.dm_exec_sessions s
LEFT JOIN sys.dm_exec_requests r ON r.session_id = s.session_id
WHERE s.session_id = @spid;

SELECT
    DB_NAME(database_id) AS DatabaseName,
    COUNT(*) AS PageCount,
    COUNT(*) * 8 / 1024 AS BufferPool_MB,
    MAX(free_space_in_bytes) AS MaxFreeBytes
FROM sys.dm_os_buffer_descriptors
WHERE database_id NOT IN (32767)
GROUP BY DB_NAME(database_id)
ORDER BY BufferPool_MB DESC;
SELECT 
    [object_name], 
    [counter_name], 
    [cntr_value] AS PageLifeExpectancy_sec
FROM sys.dm_os_performance_counters
WHERE [counter_name] = 'Page life expectancy';
