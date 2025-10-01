-- scripts/03_apply_qs_hints.sql
-- Dodajemy Query Store Hint, np. MAXDOP = 1 oraz DISABLE_OPTIMIZER_ROWGOAL
-- Identyfikacja query_id (dla proca) + apply hints

USE QSH_Lab;
GO

DECLARE @query_id BIGINT;
SELECT TOP (1) @query_id = qsq.query_id
FROM sys.query_store_query_text qt
JOIN sys.query_store_query qsq ON qsq.query_text_id = qt.query_text_id
WHERE qt.query_sql_text LIKE '%SumByCat%'
ORDER BY qsq.last_execution_time DESC;

-- Dodajemy hinty (w niektórych buildach funkcja to sys.sp_query_store_set_hints)
EXEC sys.sp_query_store_set_hints @query_id = @query_id,
    @value = N'OPTION (MAXDOP 1, USE HINT (''DISABLE_OPTIMIZER_ROWGOAL''))';

-- Podgląd aktywnych hintów
SELECT * FROM sys.query_store_query_hints WHERE query_id = @query_id;
