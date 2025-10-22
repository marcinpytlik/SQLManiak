/* QSH_Report_Hints.sql
   Pokaż aktywne Query Store Hints w bazie.
*/
SET NOCOUNT ON;

SELECT qsq.query_id,
       qsqt.query_sql_text,
       qsqh.hint_text,
       qsqh.is_enabled,
       qsqh.last_modified,
       qsqh.reason
FROM sys.query_store_query_hints AS qsqh
JOIN sys.query_store_query AS qsq ON qsq.query_id = qsqh.query_id
JOIN sys.query_store_query_text AS qsqt ON qsqt.query_text_id = qsq.query_text_id
ORDER BY qsqh.last_modified DESC;
