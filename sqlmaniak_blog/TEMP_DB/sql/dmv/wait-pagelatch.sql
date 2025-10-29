
-- dmv/wait-pagelatch.sql
-- Szukaj PAGELATCH na tempdb (resource_description zaczyna sie od 2:)
SELECT wait_type, blocking_session_id, session_id, resource_description, wait_duration_ms
FROM sys.dm_os_waiting_tasks
WHERE wait_type LIKE 'PAGELATCH_%' AND resource_description LIKE '2:%'
ORDER BY wait_duration_ms DESC;
