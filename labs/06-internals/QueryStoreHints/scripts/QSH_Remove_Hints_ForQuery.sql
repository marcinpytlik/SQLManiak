/* QSH_Remove_Hints_ForQuery.sql
   Usuń wszystkie Query Store Hints dla wybranego query_id.
*/
DECLARE @query_id bigint = 0; -- TODO: wstaw

EXEC sys.sp_query_store_remove_hints
     @query_id = @query_id;

SELECT * FROM sys.query_store_query_hints WHERE query_id = @query_id;
