
# 01 – DELETE vs TRUNCATE

**Idea:** Oba usuwają dane, ale robią to na innym poziomie i z innymi konsekwencjami dla logu i metadanych.

## Setup (lab)
```sql
USE tempdb;
GO
IF OBJECT_ID('dbo.DemoDeleteTruncate') IS NOT NULL DROP TABLE dbo.DemoDeleteTruncate;
CREATE TABLE dbo.DemoDeleteTruncate
(
    Id INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    Category INT NOT NULL,
    Payload CHAR(100) NULL
);

INSERT INTO dbo.DemoDeleteTruncate(Category, Payload)
SELECT TOP (100000) ABS(CHECKSUM(NEWID())) % 100, 'x'
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
DBCC SQLPERF(LOGSPACE); -- zapisz rozmiar tempdb log
```

## Test
```sql
-- DELETE (wiersz po wierszu – pełne logowanie)
BEGIN TRAN;
DELETE FROM dbo.DemoDeleteTruncate WHERE Category = 7;
ROLLBACK;

-- TRUNCATE (dealokacja całych stron/extentów, reset IDENTITY)
TRUNCATE TABLE dbo.DemoDeleteTruncate;
```

## Obserwacje
- `DELETE`: loguje każdą usuniętą krotkę; nie resetuje `IDENTITY`.
- `TRUNCATE`: loguje de‑alokacje stron; **resetuje `IDENTITY`**; wymaga braku FK na tabelę.

## Weryfikacja
```sql
DBCC CHECKIDENT ('dbo.DemoDeleteTruncate', NORESEED);
SELECT log_reuse_wait, log_reuse_wait_desc FROM sys.databases WHERE name = 'tempdb';
```

## Wnioski
- `TRUNCATE` jest szybszy i lżejszy dla logu, ale ma ograniczenia.
- `DELETE` daje kontrolę (filtry, trigger AFTER DELETE), ale generuje większy log.
