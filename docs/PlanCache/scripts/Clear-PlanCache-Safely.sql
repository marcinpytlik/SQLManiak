/* Clear-PlanCache-Safely.sql
   Precyzyjne czyszczenie cache:
   1) po plan_handle
   2) po query_hash (wszystkie plany dla danego hash)
   Wymaga roztropności – używaj na TEST/DR, a na PROD po weryfikacji i poza szczytem.
*/
SET NOCOUNT ON;

-----------------------------------------
-- 1) Usunięcie konkretnego planu:
-----------------------------------------
DECLARE @plan_handle varbinary(64) = NULL;

-- TODO: wstaw znaleziony plan_handle (np. z Get-PlanCache-Top10.sql)
-- SET @plan_handle = 0x...;

IF @plan_handle IS NOT NULL
BEGIN
    PRINT 'Usuwam plan po plan_handle...';
    DBCC FREEPROCCACHE(@plan_handle);
END
ELSE
    PRINT 'Pomińnięto: @plan_handle = NULL';

-----------------------------------------
-- 2) Usunięcie wszystkich planów dla query_hash:
-----------------------------------------
DECLARE @query_hash binary(8) = NULL;

-- Znajdź query_hash, np. z Detect-PlanCache-Duplicates.sql
-- SET @query_hash = 0x...;

IF @query_hash IS NOT NULL
BEGIN
    PRINT 'Usuwam wszystkie plany dla query_hash...';

    ;WITH H AS
    (
        SELECT DISTINCT qs.plan_handle
        FROM sys.dm_exec_query_stats AS qs
        WHERE qs.query_hash = @query_hash
    )
    SELECT * INTO #plans_to_remove FROM H;

    DECLARE @ph varbinary(64);
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT plan_handle FROM #plans_to_remove;

    OPEN c;
    FETCH NEXT FROM c INTO @ph;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DBCC FREEPROCCACHE(@ph);
        FETCH NEXT FROM c INTO @ph;
    END
    CLOSE c; DEALLOCATE c;

    DROP TABLE #plans_to_remove;
END
ELSE
    PRINT 'Pomińnięto: @query_hash = NULL';

-- Opcjonalnie: odśwież DMV
-- DBCC FREESYSTEMCACHE ('SQL Plans'); -- Używaj ostrożnie – globalne.
