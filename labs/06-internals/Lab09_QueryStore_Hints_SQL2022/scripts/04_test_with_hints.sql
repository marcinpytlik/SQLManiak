-- scripts/04_test_with_hints.sql
USE QSH_Lab;
GO
DBCC FREEPROCCACHE;
GO
EXEC dbo.SumByCat @cat = 1;
EXEC dbo.SumByCat @cat = 2;
GO 20

-- Porównanie po hintach
SELECT TOP (20)
    qsq.query_id, qsp.plan_id, rs.count_executions, rs.avg_duration, rs.avg_cpu_time, rs.avg_logical_io_reads,
    qsh.query_hint_text
FROM sys.query_store_query_text qt
JOIN sys.query_store_query qsq ON qsq.query_text_id = qt.query_text_id
JOIN sys.query_store_plan qsp ON qsp.query_id = qsq.query_id
JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qsp.plan_id
LEFT JOIN sys.query_store_query_hints qsh ON qsh.query_id = qsq.query_id
WHERE qt.query_sql_text LIKE '%SumByCat%'
ORDER BY rs.avg_duration DESC;
