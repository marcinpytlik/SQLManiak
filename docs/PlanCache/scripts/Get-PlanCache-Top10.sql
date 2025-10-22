/* Get-PlanCache-Top10.sql
   Top 10 planów wg użycia i rozmiaru. Wymaga VIEW SERVER STATE.
*/
SET NOCOUNT ON;

SELECT TOP (10)
    DB_NAME(t.dbid)              AS DatabaseName,
    cp.objtype,
    cp.usecounts,
    cp.size_in_bytes / 1024      AS SizeKB,
    t.text                       AS SQLText,
    qs.execution_count,
    qs.total_elapsed_time / 1000 AS TotalElapsedMs,
    cp.plan_handle
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS t
OUTER APPLY sys.dm_exec_query_stats AS qs
WHERE qs.plan_handle = cp.plan_handle
ORDER BY cp.usecounts DESC, cp.size_in_bytes DESC;
