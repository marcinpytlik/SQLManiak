-- scripts/03_inspect_variants.sql
-- Inspekcja wariantów PSP: Query Store + DMVs
USE PSP_Lab;
GO
-- Query Store
SELECT TOP (20)
    qsq.query_id, qsp.plan_id, qsp.is_forced_plan, qsp.is_parallel_plan,
    rs.count_executions, rs.avg_duration, rs.avg_cpu_time, rs.avg_logical_io_reads
FROM sys.query_store_query_text AS qt
JOIN sys.query_store_query AS qsq ON qsq.query_text_id = qt.query_text_id
JOIN sys.query_store_plan AS qsp ON qsp.query_id = qsq.query_id
JOIN sys.query_store_runtime_stats AS rs ON rs.plan_id = qsp.plan_id
WHERE qt.query_sql_text LIKE '%GetOrdersByRegion%'
ORDER BY rs.count_executions DESC;

-- DMVs: pokaż skompilowane plany i atrybuty PSP (jeśli dostępne w Twojej wersji)
SELECT cp.plan_handle, cp.usecounts, qs.total_elapsed_time, qs.total_logical_reads
FROM sys.dm_exec_cached_plans AS cp
JOIN sys.dm_exec_query_stats AS qs ON cp.plan_handle = qs.plan_handle
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
WHERE st.text LIKE '%GetOrdersByRegion%';
