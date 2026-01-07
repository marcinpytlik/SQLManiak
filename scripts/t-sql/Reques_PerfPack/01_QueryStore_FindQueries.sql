/* 01_QueryStore_FindQueries.sql
   Znajdź zapytania dotykające tabeli w podanym oknie czasu.
   Wymaga włączonego Query Store.

   Ustaw datę incydentu:
*/
DECLARE @From datetime2(0) = '2026-01-07T15:00:00';
DECLARE @To   datetime2(0) = '2026-01-07T15:25:00';

-- Szybki sanity check: czy Query Store jest włączony i zbiera runtime?
SELECT
    actual_state_desc, current_storage_size_mb, max_storage_size_mb,
    stale_query_threshold_days, interval_length_minutes, capture_mode_desc
FROM sys.database_query_store_options;

;WITH Q AS
(
    SELECT
        qsq.query_id,
        qsp.plan_id,
        qsq.query_hash,
        qsq.query_parameterization_type_desc,
        qt.query_sql_text
    FROM sys.query_store_query AS qsq
    JOIN sys.query_store_query_text AS qt
      ON qsq.query_text_id = qt.query_text_id
    JOIN sys.query_store_plan AS qsp
      ON qsq.query_id = qsp.query_id
    WHERE qt.query_sql_text LIKE '%nazwa_tabeli%'
       OR qt.query_sql_text LIKE '%nazwa_tabeli%' 
),
R AS
(
    SELECT
        rs.plan_id,
        rsi.start_time,
        rsi.end_time,
        rs.count_executions,
        rs.avg_duration,
        rs.max_duration,
        rs.avg_cpu_time,
        rs.avg_logical_io_reads,
        rs.avg_physical_io_reads,
        rs.avg_logical_io_writes,
        rs.avg_query_max_used_memory,
        rs.avg_tempdb_space_used
    FROM sys.query_store_runtime_stats AS rs
    JOIN sys.query_store_runtime_stats_interval AS rsi
      ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
    WHERE rsi.start_time >= @From
      AND rsi.end_time   <= @To
)
SELECT TOP (200)
    DB_NAME() AS [database_name],
    q.query_id, q.plan_id, q.query_hash,
    r.start_time, r.end_time,
    r.count_executions,
    r.avg_duration/1000.0 AS avg_duration_ms,
    r.max_duration/1000.0 AS max_duration_ms,
    r.avg_cpu_time/1000.0 AS avg_cpu_ms,
    r.avg_logical_io_reads,
    r.avg_physical_io_reads,
    r.avg_logical_io_writes,
    r.avg_query_max_used_memory AS avg_grant_kb,
    r.avg_tempdb_space_used AS avg_tempdb_kb,
    LEFT(REPLACE(REPLACE(q.query_sql_text, CHAR(10),' '), CHAR(13),' '), 4000) AS query_text_4k
FROM Q q
JOIN R r
  ON q.plan_id = r.plan_id
ORDER BY r.max_duration DESC, r.avg_duration DESC;

-- Plany dla TOP problemów (podstaw TOP w razie potrzeby):
SELECT TOP (20)
    q.query_id, q.plan_id,
    q.query_hash,
    TRY_CONVERT(xml, p.query_plan) AS query_plan_xml
FROM Q q
JOIN sys.query_store_plan p ON p.plan_id = q.plan_id
ORDER BY q.plan_id DESC;
