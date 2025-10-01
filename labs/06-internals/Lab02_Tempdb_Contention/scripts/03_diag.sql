-- scripts/03_diag.sql
-- Diagnoza contention: WAIT-y, latch-e, hot pages.

-- 1) Wait stats (PAGELATCH)
SELECT TOP (20) *
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'PAGELATCH%'
ORDER BY wait_time_ms DESC;

-- 2) Aktywne żądania z PAGELATCH (w tempdb)
SELECT r.session_id, r.status, r.command, r.wait_type, r.wait_time, r.wait_resource, r.cpu_time, r.total_elapsed_time
FROM sys.dm_exec_requests AS r
WHERE r.wait_type LIKE 'PAGELATCH%'
ORDER BY r.total_elapsed_time DESC;

-- 3) Latch stats
SELECT TOP (50) latch_class, waiting_requests_count, wait_time_ms
FROM sys.dm_os_latch_stats
ORDER BY wait_time_ms DESC;

-- 4) Pliki tempdb (czy równe rozmiary?)
SELECT name, size*8/1024 AS size_MB, growth*8/1024 AS growth_MB, physical_name
FROM tempdb.sys.database_files
ORDER BY file_id;
