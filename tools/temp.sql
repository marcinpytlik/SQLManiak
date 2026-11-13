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
z3:


SET NOCOUNT ON;

DECLARE @TableName nvarchar(256) =
    N'globus_RAPORTY_0000_S';

DECLARE @HoursBack int = 24;

DECLARE @FromTime datetimeoffset =
    DATEADD(HOUR, -@HoursBack, SYSDATETIMEOFFSET());

SELECT TOP (100)
    DB_NAME() AS DatabaseName,
    q.query_id,
    p.plan_id,
    qt.query_sql_text,
    ws.wait_category_desc,

    SUM(ws.total_query_wait_time_ms) AS TotalWaitMs,

    SUM(ws.total_query_wait_time_ms) / 1000.0
        AS TotalWaitSec,

    MAX(ws.max_query_wait_time_ms) AS MaxWaitMs,

    MIN(rsi.start_time) AS FirstInterval,
    MAX(rsi.end_time) AS LastInterval

FROM sys.query_store_wait_stats AS ws

INNER JOIN sys.query_store_plan AS p
    ON ws.plan_id = p.plan_id

INNER JOIN sys.query_store_query AS q
    ON p.query_id = q.query_id

INNER JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id

INNER JOIN sys.query_store_runtime_stats_interval AS rsi
    ON ws.runtime_stats_interval_id =
       rsi.runtime_stats_interval_id

WHERE
    ws.wait_category_desc = N'Lock'
    AND rsi.end_time >= @FromTime
    AND (
        qt.query_sql_text LIKE N'%' + @TableName + N'%'
        OR qt.query_sql_text LIKE N'%FETCH%'
    )

GROUP BY
    q.query_id,
    p.plan_id,
    qt.query_sql_text,
    ws.wait_category_desc

ORDER BY
    TotalWaitMs DESC;

z4:

-- Test 1: Query Store - tryb, rejestrowanie wait stats i wykorzystanie przestrzeni
SELECT
    actual_state_desc,
    wait_stats_capture_mode_desc,
    query_capture_mode_desc,
    current_storage_size_mb,
    max_storage_size_mb,
    readonly_reason
FROM sys.database_query_store_options;

z5:

-- Test 2: historyczne oczekiwania Lock bez filtra czasu i nazwy tabeli
SELECT TOP (30)
    p.query_id,
    ws.plan_id,
    ws.wait_category_desc,
    SUM(ws.total_query_wait_time_ms) AS TotalWaitMs,
    MAX(ws.max_query_wait_time_ms) AS MaxWaitMs,
    MIN(i.start_time) AS FirstInterval,
    MAX(i.end_time) AS LastInterval
FROM sys.query_store_wait_stats AS ws
JOIN sys.query_store_plan AS p
    ON ws.plan_id = p.plan_id
JOIN sys.query_store_runtime_stats_interval AS i
    ON ws.runtime_stats_interval_id =
       i.runtime_stats_interval_id
WHERE ws.wait_category_desc = N'Lock'
GROUP BY
    p.query_id,
    ws.plan_id,
    ws.wait_category_desc
ORDER BY TotalWaitMs DESC;

z6:

-- Test 3: teksty zapytań Query Store zawierające nazwę tabeli
SELECT TOP (50)
    q.query_id,
    qt.query_sql_text
FROM sys.query_store_query AS q
JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
WHERE qt.query_sql_text LIKE
    N'%globus_RAPORTY_0000_S%'
ORDER BY q.query_id DESC;

z7:

-- Historyczne oczekiwania Lock dla zapytań odwołujących się do GLOBUS_RAPORTY_0000_S
-- Bez ograniczenia czasowego; Query Store nie identyfikuje sesji blokującej.
SELECT TOP (50)
    q.query_id,
    p.plan_id,
    qt.query_sql_text,
    SUM(ws.total_query_wait_time_ms)
        AS TotalLockWaitMs,
    MAX(ws.max_query_wait_time_ms)
        AS MaxLockWaitMs,
    MIN(i.start_time) AS FirstInterval,
    MAX(i.end_time) AS LastInterval
FROM sys.query_store_query AS q
JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan AS p
    ON q.query_id = p.query_id
JOIN sys.query_store_wait_stats AS ws
    ON p.plan_id = ws.plan_id
JOIN sys.query_store_runtime_stats_interval AS i
    ON ws.runtime_stats_interval_id =
       i.runtime_stats_interval_id
WHERE ws.wait_category_desc = N'Lock'
  AND qt.query_sql_text LIKE
      N'%GLOBUS_RAPORTY_0000_S%'
GROUP BY
    q.query_id,
    p.plan_id,
    qt.query_sql_text
ORDER BY TotalLockWaitMs DESC;
