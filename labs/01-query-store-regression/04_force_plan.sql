USE QS_Lab;
GO
-- Zidentyfikuj query w Query Store
SELECT TOP (5)
      qsq.query_id, qsq.query_hash, qsqt.query_sql_text, p.plan_id
FROM sys.query_store_query qsq
JOIN sys.query_store_query_text qsqt ON qsqt.query_text_id = qsq.query_text_id
JOIN sys.query_store_plan p ON p.query_id = qsq.query_id
WHERE qsqt.query_sql_text LIKE '%SELECT SUM(Amount) FROM dbo.Sales%'
ORDER BY qsq.query_id DESC;

-- Podmień poniżej właściwe query_id i plan_id na najlepszy plan:
-- EXEC sys.sp_query_store_force_plan @query_id = <QID>, @plan_id = <PID>;

-- podgląd metryk
SELECT TOP (20) * 
FROM sys.query_store_runtime_stats rs
ORDER BY rs.avg_duration DESC;
