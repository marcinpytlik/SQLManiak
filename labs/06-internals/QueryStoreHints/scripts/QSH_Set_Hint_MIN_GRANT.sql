/* QSH_Set_Hint_MIN_GRANT.sql
   Zapewnij minimalny grant, by ograniczyć spille do tempdb (ostrożnie).
*/
DECLARE @query_id bigint = 0;        -- TODO: wstaw
DECLARE @percent  decimal(5,2) = 2;  -- TODO: dopasuj (np. 1..5)

EXEC sys.sp_query_store_set_hints
     @query_id = @query_id,
     @value = N'OPTION (MIN_GRANT_PERCENT = ' + CONVERT(varchar(32), @percent) + N')';

SELECT * FROM sys.query_store_query_hints WHERE query_id = @query_id;
