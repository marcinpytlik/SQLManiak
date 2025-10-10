
# 06 – Tempdb Allocations

**Idea:** Zrozumienie alokacji w tempdb (PFS/GAM/SGAM) pomaga przy zakleszczeniach i hotspotach alokacyjnych.

## Setup
```sql
USE tempdb;
GO
IF OBJECT_ID('dbo.DemoTemp') IS NOT NULL DROP TABLE dbo.DemoTemp;
CREATE TABLE dbo.DemoTemp (Id INT IDENTITY, Pad CHAR(4000) DEFAULT 'x');
GO
```

## Test równoległy (uruchom w kilku sesjach)
```sql
INSERT INTO dbo.DemoTemp DEFAULT VALUES;
GO 10000
```

## Podgląd alokacji
```sql
SELECT * 
FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('dbo.DemoTemp'), NULL, NULL, 'DETAILED');
```

## Wnioski
- Wielowątkowe inserty w małe strony mogą tworzyć hotspoty na PFS.
- Więcej plików tempdb (np. 1 plik na 4 rdzenie, max 8) pomaga rozproszyć alokacje.
