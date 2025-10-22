/* QSH_Set_Hint_Compat150.sql
   Wymuś zachowanie optymalizatora jak w poziomie 150 (SQL 2019).
*/
DECLARE @query_id bigint = 0; -- TODO: wstaw

EXEC sys.sp_query_store_set_hints
     @query_id = @query_id,
     @value = N'OPTION (QUERY_OPTIMIZER_COMPATIBILITY_LEVEL_150)';

SELECT * FROM sys.query_store_query_hints WHERE query_id = @query_id;
