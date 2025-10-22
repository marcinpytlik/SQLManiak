/* QSH_Set_Hint_DISABLE_PS.sql
   Tymczasowo wyłącz parameter sniffing dla danego query_id.
*/
DECLARE @query_id bigint = 0; -- TODO: wstaw

EXEC sys.sp_query_store_set_hints
     @query_id = @query_id,
     @value = N'OPTION (USE HINT(''DISABLE_PARAMETER_SNIFFING''))';

SELECT * FROM sys.query_store_query_hints WHERE query_id = @query_id;
