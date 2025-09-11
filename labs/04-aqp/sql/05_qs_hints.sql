
PRINT '--- Lab 5: Query Store Hints ---';
SET NOCOUNT ON;
USE AQP_Lab;

-- 1) Zidentyfikuj query_id dla kwerendy z Labu 2 (GROUP BY grp).
SELECT TOP (5) qsq.query_id, qsq.last_execution_time, qt.query_sql_text
FROM sys.query_store_query_text qt
JOIN sys.query_store_query qsq ON qsq.query_text_id = qt.query_text_id
WHERE qt.query_sql_text LIKE N'%GROUP BY grp%'
ORDER BY qsq.last_execution_time DESC;

-- 2) Skopiuj odpowiedni query_id i nałóż hinty (przykład):
--    MAXDOP 1 + OPTIMIZE FOR UNKNOWN (przykładowo, bez dotykania kodu aplikacji).
--    UWAGA: WSTAW NUMER query_id poniżej.
-- EXEC sys.sp_query_store_set_hints @query_id = <WSTAW_QUERY_ID>,
--      @query_hints = N'OPTION (MAXDOP 1, OPTIMIZE FOR UNKNOWN)';

-- 3) Weryfikacja aktywnych hintów i ewentualne czyszczenie:
-- SELECT * FROM sys.query_store_query_hints WHERE query_id = <WSTAW_QUERY_ID>;
-- EXEC sys.sp_query_store_clear_hints @query_id = <WSTAW_QUERY_ID>;
