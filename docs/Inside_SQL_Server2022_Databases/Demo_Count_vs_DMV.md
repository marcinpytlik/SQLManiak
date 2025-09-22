# Demo: COUNT(*) vs DMV (sys.dm_db_partition_stats)


## Cel
Pokazanie różnicy między:
- **`SELECT COUNT(*)`** – pełny skan tabeli, blokady, wolniejsze działanie,  
- **`sys.dm_db_partition_stats`** – szybki odczyt liczników z metadanych.

---

## Krok 0 – Przygotowanie danych
```sql
USE tempdb;
GO
IF OBJECT_ID('dbo.BigTable') IS NOT NULL DROP TABLE dbo.BigTable;
GO
CREATE TABLE dbo.BigTable
(
    id INT IDENTITY(1,1) PRIMARY KEY,
    filler CHAR(100) NOT NULL DEFAULT REPLICATE('X',100)
);
GO

-- Wstaw ok. 2 mln wierszy (czasem warto mniej/więcej, żeby poczuć różnicę)
;WITH n AS (SELECT 1 AS n UNION ALL SELECT 1)
, l1 AS (SELECT 1 FROM n a CROSS JOIN n b CROSS JOIN n c CROSS JOIN n d)      -- 16
, l2 AS (SELECT 1 FROM l1 a CROSS JOIN l1 b)                                  -- 256
, l3 AS (SELECT 1 FROM l2 a CROSS JOIN l2 b)                                  -- 65 536
INSERT INTO dbo.BigTable (filler)
SELECT TOP (2000000) REPLICATE('X',100)
FROM l3 a CROSS JOIN l3 b;
GO
```

---

## Sesja A – blokada tabeli
W pierwszym oknie (Sesja A):
```sql
USE tempdb;
GO
BEGIN TRAN;
-- Załóż X-lock na tabelę
SELECT 1
FROM dbo.BigTable WITH (TABLOCKX, HOLDLOCK);

-- Zostaw transakcję otwartą!
```

---

## Sesja B – porównanie COUNT(*) i DMV

### 1. COUNT(*) – powinno zawisnąć
```sql
USE tempdb;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT COUNT(*) AS count_via_scan
FROM dbo.BigTable;
```

Podczas zawisu sprawdź kto blokuje:
```sql
SELECT
    r.session_id,
    r.status,
    r.wait_type,
    r.blocking_session_id,
    t.text AS sql_text
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id > 50;
```
Oczekiwany `wait_type`: **LCK_M_S**.

### 2. DMV – wynik natychmiast
W drugim zapytaniu w Sesji B:
```sql
USE tempdb;
GO
SELECT
    t.name AS table_name,
    SUM(ps.row_count) AS row_count_metadata
FROM sys.dm_db_partition_stats AS ps
JOIN sys.tables AS t
  ON ps.object_id = t.object_id
WHERE t.name = 'BigTable'
  AND ps.index_id IN (0,1)
GROUP BY t.name;
```

---

## Sesja A – sprzątanie
Wróć do Sesji A i zwolnij blokadę:
```sql
COMMIT; -- albo ROLLBACK
```

Po tym `COUNT(*)` w Sesji B zakończy się.

---

## Bonus – porównanie bez blokad
Na czysto:
```sql
USE tempdb;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT COUNT(*) AS count_via_scan
FROM dbo.BigTable;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

-- DMV dla porównania
SELECT
    t.name AS table_name,
    SUM(ps.row_count) AS row_count_metadata
FROM sys.dm_db_partition_stats ps
JOIN sys.tables t
  ON ps.object_id = t.object_id
WHERE t.name = 'BigTable'
  AND ps.index_id IN (0,1)
GROUP BY t.name;
```

---

## Diagram blokad (ASCII)
```
 Sesja A (okno 1)                   Sesja B (okno 2)
 -----------------                  -----------------
 BEGIN TRAN                         SELECT COUNT(*)
 SELECT ... WITH (TABLOCKX)  --->   [czeka na S-lock]
   |                                      ^
   | X-lock (exclusive)                   |
   |--------------------------------------|
                                        blokada

 Sesja B (okno 2) – DMV
 ----------------------
 SELECT ... FROM sys.dm_db_partition_stats
  --> działa natychmiast (nie potrzebuje S-lock)
```

---

## Wnioski
- `COUNT(*)` = dokładny wynik, ale kosztowny (pełny scan, blokady).  
- `sys.dm_db_partition_stats` = szybki wynik z metadanych, nie blokuje się na X-lockach.  
- DMV świetne do monitoringu i raportów, `COUNT(*)` tylko gdy potrzebna pełna spójność transakcyjna.
