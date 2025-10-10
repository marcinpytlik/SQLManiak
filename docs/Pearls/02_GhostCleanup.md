
# 02 – Ghost Cleanup

**Idea:** Po `DELETE` wiersze stają się „ghosts” (oznaczone do usunięcia). Proces **Ghost Cleanup** fizycznie sprząta je w tle.

## Setup
```sql
USE tempdb;
GO
IF OBJECT_ID('dbo.DemoGhost') IS NOT NULL DROP TABLE dbo.DemoGhost;
CREATE TABLE dbo.DemoGhost (Id INT IDENTITY PRIMARY KEY, Payload CHAR(200));
INSERT INTO dbo.DemoGhost(Payload) SELECT TOP (50000) 'x' FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
```

## Test
```sql
DELETE TOP (40000) FROM dbo.DemoGhost; -- dużo ghostów
CHECKPOINT;
```

## Podgląd (poziom DMV)
```sql
SELECT * FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('dbo.DemoGhost'), NULL, NULL, 'DETAILED');
-- poszukaj stron z dużą liczbą usuniętych rekordów

-- aktywność procesu
SELECT * 
FROM sys.dm_exec_requests 
WHERE command IN ('GHOST CLEANUP','TASK MANAGER'); -- wskaźnikowo
```

## Wnioski
- Ghost cleanup działa opportunistycznie – może się „spóźniać” przy dużym obciążeniu.
- Skany mogą omijać ghosty, ale nadal „płacisz” za ich obecność na stronach (fragmentacja).
