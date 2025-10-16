
-- 03_ModifyData.sql
-- Wymusza copy‑on‑write: UPDATE/DELETE/INSERT oraz opcjonalnie rebuild indeksu.

:setvar DatabaseName SnapshotDemoDB

USE [$(DatabaseName)];
GO

PRINT '>> Update 30% wierszy — przesunie dużo stron.';
UPDATE s
   SET Amount = Amount * 1.05
FROM dbo.Sales AS s
WHERE s.Id % 10 IN (0,1,2); -- ~30%

CHECKPOINT;

PRINT '>> Delete 10% wierszy — kolejne zmiany stron.';
DELETE FROM dbo.Sales
WHERE Id % 10 = 5;

CHECKPOINT;

PRINT '>> Insert 200k wierszy.';
;WITH gen AS
(
  SELECT TOP (200000)
         ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
  FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Sales(CustomerId, OrderDate, Amount, Payload)
SELECT (n % 100000) + 1,
       DATEADD(day, -(n % 365), SYSUTCDATETIME()),
       (n % 10000) * 0.01,
       REPLICATE('Y', 200)
FROM gen;

CHECKPOINT;

PRINT '>> Gotowe. Sprawdź teraz rozmiar snapshotu.';
