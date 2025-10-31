-- ✅ Zużycie CPU per baza danych (z poprawką na NULL)
WITH QueryCPU AS (
    SELECT 
        CONVERT(INT, pa.value) AS DatabaseID,
        qs.total_worker_time / 1000.0 AS CPU_ms
    FROM sys.dm_exec_query_stats AS qs
    CROSS APPLY sys.dm_exec_plan_attributes(qs.plan_handle) AS pa
    WHERE pa.attribute = 'dbid'
)
SELECT 
    DB_NAME(DatabaseID) AS DatabaseName,
    COUNT(*) AS Queries,
    SUM(CPU_ms) AS TotalCPU_ms,
    AVG(CPU_ms) AS AvgCPU_ms
FROM QueryCPU
WHERE DatabaseID > 4   -- pomijamy bazy systemowe master, model, msdb, tempdb
GROUP BY DB_NAME(DatabaseID)
ORDER BY TotalCPU_ms DESC;
