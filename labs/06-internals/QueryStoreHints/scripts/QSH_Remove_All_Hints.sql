/* QSH_Remove_All_Hints.sql
   Usuwa WSZYSTKIE hints w bieżącej bazie. Używaj z rozwagą.
*/
DECLARE @all bit = 1; -- sanity flag
IF @all = 1
BEGIN
    DECLARE @qid bigint;
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT query_id FROM sys.query_store_query_hints;
    OPEN c;
    FETCH NEXT FROM c INTO @qid;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sys.sp_query_store_remove_hints @query_id = @qid;
        FETCH NEXT FROM c INTO @qid;
    END
    CLOSE c; DEALLOCATE c;
END;

SELECT COUNT(*) AS RemainingHints FROM sys.query_store_query_hints;
