SELECT 
    DB_NAME(st.dbid) AS DatabaseName,
    SUM(qs.total_worker_time) / 1000.0 AS TotalCPU_ms,
    SUM(qs.execution_count) AS ExecutionCount,
    (SUM(qs.total_worker_time) / SUM(qs.execution_count)) / 1000.0 AS AvgCPU_ms_per_exec
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
GROUP BY DB_NAME(st.dbid)
ORDER BY TotalCPU_ms DESC;