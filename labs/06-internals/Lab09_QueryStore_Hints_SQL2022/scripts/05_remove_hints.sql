-- scripts/05_remove_hints.sql
USE QSH_Lab;
GO
DECLARE @query_id BIGINT;
SELECT TOP (1) @query_id = qsq.query_id
FROM sys.query_store_query_text qt
JOIN sys.query_store_query qsq ON qsq.query_text_id = qt.query_text_id
WHERE qt.query_sql_text LIKE '%SumByCat%'
ORDER BY qsq.last_execution_time DESC;

EXEC sys.sp_query_store_clear_hints @query_id = @query_id;
-- Potwierdź
SELECT * FROM sys.query_store_query_hints WHERE query_id = @query_id;
