SELECT
  s.session_id,
  s.login_name,
  s.host_name,
  s.program_name,
  r.status,
  DB_NAME(r.database_id) AS db,
  r.command,
  r.wait_type,
  r.cpu_time,
  r.total_elapsed_time,
  r.reads,
  r.writes,
  t.text AS sql_text
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE s.is_user_process = 1
ORDER BY r.total_elapsed_time DESC;

DECLARE @trace NVARCHAR(4000) =
 (SELECT TOP(1) path FROM sys.traces WHERE is_default = 1);
SELECT
  te.name AS event_name,
  t.DatabaseName,
  t.ObjectName,
  t.HostName,
  t.LoginName,
  t.ApplicationName,
  t.StartTime
FROM ::fn_trace_gettable(@trace, DEFAULT) t
JOIN sys.trace_events te ON te.trace_event_id = t.EventClass
WHERE t.DatabaseName = 'YourDatabase'
  AND t.StartTime > DATEADD(day, -1, GETDATE())
ORDER BY t.StartTime DESC;
