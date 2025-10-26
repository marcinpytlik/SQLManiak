USE [AdventureWorks2022];
GO

-- Ostatnio wykonywane zapytania
SELECT TOP 20 
    qs.query_id, p.plan_id, rs.avg_duration, rs.last_execution_time
FROM sys.query_store_query AS qs
JOIN sys.query_store_plan AS p ON qs.query_id = p.query_id
JOIN sys.query_store_runtime_stats AS rs ON p.plan_id = rs.plan_id
ORDER BY rs.last_execution_time DESC;

-- Zapytania z największą liczbą planów (niestabilne)
SELECT query_id, COUNT(DISTINCT plan_id) AS plan_count
FROM sys.query_store_plan
GROUP BY query_id
HAVING COUNT(DISTINCT plan_id) > 1
ORDER BY plan_count DESC;
