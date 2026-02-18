/* Blocking and long running requests */
SET NOCOUNT ON;

-- Top blockers (sessions that block others)
;WITH blockers AS
(
    SELECT
        r.blocking_session_id AS blocker_session_id,
        COUNT(*) AS blocked_count
    FROM sys.dm_exec_requests r
    WHERE r.blocking_session_id <> 0
    GROUP BY r.blocking_session_id
)
SELECT TOP (20)
    b.blocker_session_id,
    b.blocked_count,
    s.login_name,
    s.host_name,
    s.program_name,
    s.status
FROM blockers b
JOIN sys.dm_exec_sessions s ON s.session_id = b.blocker_session_id
ORDER BY b.blocked_count DESC;

PRINT '---';

-- Long running requests (> 5 minutes) - tweak threshold
DECLARE @threshold_ms int = 5 * 60 * 1000;

SELECT
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
    s.login_name,
    s.host_name,
    s.program_name,
    SUBSTRING(t.text, (r.statement_start_offset/2)+1,
        CASE WHEN r.statement_end_offset = -1
             THEN (DATALENGTH(t.text) - r.statement_start_offset)/2 + 1
             ELSE (r.statement_end_offset - r.statement_start_offset)/2 + 1
        END) AS StatementText
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id <> @@SPID
  AND r.total_elapsed_time >= @threshold_ms
ORDER BY r.total_elapsed_time DESC;
