/* DMV: Snapshot aktywnych poleceń (SPID < 50) */
SET NOCOUNT ON;

SELECT session_id,
       command,
       wait_type,
       wait_time,
       percent_complete
FROM sys.dm_exec_requests
WHERE session_id < 50
ORDER BY session_id;
