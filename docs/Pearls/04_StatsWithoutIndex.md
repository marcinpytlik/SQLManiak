
# 04 – Statystyki bez indeksu („pseudo‑indeks”)

**Idea:** Optymalizator może oprzeć estymacje na **histogramie statystyki** nawet bez fizycznego indeksu.

## Setup
```sql
USE tempdb;
GO
IF OBJECT_ID('dbo.DemoStats') IS NOT NULL DROP TABLE dbo.DemoStats;
CREATE TABLE dbo.DemoStats (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Category INT,
    Payload CHAR(100) DEFAULT 'x'
);
INSERT INTO dbo.DemoStats(Category)
SELECT TOP (100000) ABS(CHECKSUM(NEWID())) % 1000
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
CREATE STATISTICS Stats_Category ON dbo.DemoStats(Category);
GO
```

## Test
```sql
SET STATISTICS XML ON;
SELECT COUNT(*) AS Cnt FROM dbo.DemoStats WHERE Category = 777;
SET STATISTICS XML OFF;
```

## Analiza
- W planie sprawdź **Estimated Number of Rows** – zgodność pochodzi z histogramu statystyki.
- Fizycznie to nadal skan tabeli/hoBT, ale estymacja bywa trafna jak przy indeksie.

## Wniosek
- Dobra statystyka potrafi „uratować” plan. To nie zastąpi indeksu, ale bywa zaskakująco skuteczne.
