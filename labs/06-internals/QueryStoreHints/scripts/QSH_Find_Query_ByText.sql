/* QSH_Find_Query_ByText.sql
   Znajdź query_id po fragmencie tekstu zapytania.
   Uruchom w *docelowej bazie* (tej, gdzie działa Query Store).
*/
SET NOCOUNT ON;
DECLARE @like nvarchar(4000) = N'%FROM dbo.%'; -- TODO: podmień wzorzec

SELECT TOP (50)
    qsq.query_id,
    qsqt.query_sql_text,
    DB_NAME() AS [Database],
    MAX(qsp.last_compile_start_time) AS LastCompile,
    COUNT(DISTINCT qsp.plan_id) AS Plans
FROM sys.query_store_query_text AS qsqt
JOIN sys.query_store_query AS qsq
  ON qsq.query_text_id = qsqt.query_text_id
JOIN sys.query_store_plan AS qsp
  ON qsp.query_id = qsq.query_id
WHERE qsqt.query_sql_text LIKE @like
GROUP BY qsq.query_id, qsqt.query_sql_text
ORDER BY LastCompile DESC;
