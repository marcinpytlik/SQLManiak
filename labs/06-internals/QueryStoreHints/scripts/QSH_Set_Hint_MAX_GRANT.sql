/* QSH_Set_Hint_MAX_GRANT.sql
   Nałóż limit grantu pamięci w procentach pamięci dostępnej zapytaniu.
   Przykład: 5 = maks 5% (uwaga na zbyt niski limit -> możliwe spille).
*/
DECLARE @query_id bigint = 0;      -- TODO: wstaw
DECLARE @percent  decimal(5,2) = 5; -- TODO: dopasuj (np. 5, 10)

EXEC sys.sp_query_store_set_hints
     @query_id = @query_id,
     @value = N'OPTION (MAX_GRANT_PERCENT = ' + CONVERT(varchar(32), @percent) + N')';

-- Weryfikacja
SELECT * FROM sys.query_store_query_hints WHERE query_id = @query_id;
