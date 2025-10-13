
# 05 – Auto Update / Async Stats

**Idea:** Statystyki nie aktualizują się „zawsze i wszędzie”. Liczy się próg zmian i tryb Async.

## Setup
```sql
USE tempdb; 
GO
IF OBJECT_ID('dbo.DemoAutoStats') IS NOT NULL DROP TABLE dbo.DemoAutoStats;
CREATE TABLE dbo.DemoAutoStats (Id INT IDENTITY PRIMARY KEY, K INT NOT NULL);
INSERT INTO dbo.DemoAutoStats(K) SELECT TOP (100000) 1 FROM sys.all_objects a CROSS JOIN sys.all_objects b;
CREATE STATISTICS S_K ON dbo.DemoAutoStats(K);
```

## Test progu
```sql
-- Modyfikujemy ~20% wierszy; próg dla dużych tabel to ~20% + 500 wierszy (dla starszych CE).
UPDATE TOP (25000) dbo.DemoAutoStats SET K = 2;
GO
-- sprawdź, czy zaktualizowano statystyki
SELECT name, STATS_DATE(object_id, stats_id) AS stats_date
FROM sys.stats WHERE object_id = OBJECT_ID('dbo.DemoAutoStats');
```

## Async?
```sql
EXEC sp_autostats 'dbo.DemoAutoStats', 'ON'; -- auto update włączone
ALTER DATABASE SCOPED CONFIGURATION SET ASYNCHRONOUS_STATS_UPDATE = ON; -- async
```

## Wnioski
- Przy async pierwsze zapytanie korzysta ze starych statystyk, a aktualizacja leci w tle.
- Progi i heurystyki zależą od CE (Cardinality Estimator) i wersji SQL.
