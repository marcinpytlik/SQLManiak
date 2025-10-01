-- scripts/04_test_forced_vs_unforced.sql
USE QS_Lab;
GO
-- Czyści cache planów (nie czyści QS) – wymuszenie powinno nadal działać
DBCC FREEPROCCACHE;
GO

DECLARE @r INT;
-- Odpalamy kilka razy „gęsty” parametr z wymuszonym planem (powinien być stabilny)
SET @r = 1;
SELECT COUNT(*) FROM dbo.SalesSkew WHERE Region = @r;
GO 20

-- Porównaj statystyki w Query Store
SELECT TOP (10)
    qsq.query_id, qsp.plan_id, qsp.is_forced_plan, rs.count_executions, rs.avg_duration, rs.avg_cpu_time, rs.avg_logical_io_reads
FROM sys.query_store_query_text AS qt
JOIN sys.query_store_query AS qsq ON qsq.query_text_id = qt.query_text_id
JOIN sys.query_store_plan AS qsp ON qsp.query_id = qsq.query_id
JOIN sys.query_store_runtime_stats AS rs ON rs.plan_id = qsp.plan_id
WHERE qt.query_sql_text LIKE '%SalesSkew WHERE Region = @r%'
ORDER BY qsp.is_forced_plan DESC, rs.avg_duration DESC;
