z1

;WITH RelevantSessions AS
(
    SELECT
        r.session_id
    FROM sys.dm_exec_requests AS r
    WHERE r.blocking_session_id > 0
       OR r.wait_type LIKE N'LCK_M_%'

    UNION

    SELECT
        r.blocking_session_id
    FROM sys.dm_exec_requests AS r
    WHERE r.blocking_session_id > 0
)
SELECT
    s.session_id,
    s.status AS session_status,
    r.status AS request_status,
    r.command,
    r.blocking_session_id,
    r.wait_type,
    r.wait_time AS wait_ms,
    r.wait_resource,
    r.total_elapsed_time AS elapsed_ms,
    s.open_transaction_count,
    s.transaction_isolation_level,
    s.login_name,
    s.host_name,
    s.program_name,
    DB_NAME(r.database_id) AS database_name,
    ib.event_info AS last_command,
    st.text AS active_batch
FROM RelevantSessions AS x
JOIN sys.dm_exec_sessions AS s
    ON s.session_id = x.session_id
LEFT JOIN sys.dm_exec_requests AS r
    ON r.session_id = s.session_id
LEFT JOIN sys.dm_exec_connections AS c
    ON c.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
OUTER APPLY sys.dm_exec_input_buffer(
    s.session_id, NULL
) AS ib
WHERE s.is_user_process = 1
ORDER BY
    CASE WHEN r.blocking_session_id > 0 THEN 0 ELSE 1 END,
    r.wait_time DESC;
z2

SELECT
    s.session_id,
    s.status AS session_status,
    s.open_transaction_count,
    s.transaction_isolation_level,
    s.host_name,
    s.program_name,
    c.cursor_id,
    c.name AS cursor_name,
    c.properties,
    c.creation_time,
    c.is_open,
    c.fetch_status,
    c.fetch_buffer_size,
    c.reads,
    c.writes,
    c.dormant_duration,
    c.sql_handle,
    st.text AS cursor_sql
FROM sys.dm_exec_sessions AS s
CROSS APPLY sys.dm_exec_cursors(s.session_id) AS c
OUTER APPLY sys.dm_exec_sql_text(c.sql_handle) AS st
WHERE s.is_user_process = 1
ORDER BY c.creation_time;
