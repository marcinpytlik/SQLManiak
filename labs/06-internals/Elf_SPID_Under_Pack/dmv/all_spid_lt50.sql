/* DMV: All SPID < 50 — kto jest kim teraz */
SET NOCOUNT ON;

SELECT s.session_id,
       s.login_name,
       s.host_name,
       r.command,
       r.status,
       r.wait_type,
       r.wait_time,
       r.scheduler_id,
       r.cpu_time,
       r.total_elapsed_time
FROM sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_requests AS r
  ON s.session_id = r.session_id
WHERE s.session_id < 50
ORDER BY s.session_id;
