/* QSH_List_Candidate_HeavyGrants.sql
   Kandydaci do MAX_GRANT_PERCENT:
   - Live: duże requesty w sys.dm_exec_query_memory_grants
   - Query Store: ostatnie plany zapytań z wysokim grantem (jeśli dostępne metryki)
*/
SET NOCOUNT ON;

PRINT '--- LIVE (bieżące granty) ---------------------------------';
SELECT TOP (20)
    mg.session_id,
    DB_NAME(st.dbid) AS database_name,
    mg.requested_memory_kb/1024.0 AS requested_MB,
    mg.granted_memory_kb/1024.0   AS granted_MB,
    mg.max_used_memory_kb/1024.0  AS max_used_MB,
    mg.dop,
    LEFT(st.text, 4000) AS sql_text
FROM sys.dm_exec_query_memory_grants AS mg
CROSS APPLY sys.dm_exec_sql_text(mg.sql_handle) AS st
ORDER BY mg.requested_memory_kb DESC;

PRINT '--- QUERY STORE (ostatnie aktywne plany) -------------------';
/* Uwaga: kolumny dot. grantów w QS różnią się między wersjami; poniższe to bezpieczny zarys (czas/CPU/reads)
   - dopasuj progi wg środowiska. */
SELECT TOP (50)
    qsq.query_id,
    MAX(rs.last_execution_time) AS last_exec,
    SUM(rs.count_executions)    AS execs,
    SUM(rs.total_cpu_time) / 1000.0 AS total_cpu_ms,
    SUM(rs.total_logical_reads) AS total_lreads
FROM sys.query_store_runtime_stats AS rs
JOIN sys.query_store_plan AS qsp ON qsp.plan_id = rs.plan_id
JOIN sys.query_store_query AS qsq ON qsq.query_id = qsp.query_id
GROUP BY qsq.query_id
ORDER BY total_cpu_ms DESC;
