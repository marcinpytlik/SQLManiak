
-- 02-contention-demo.sql
-- Symulacja allocation contention (wymaga wielu sesji rownoleglych)
-- Uruchom ten skrypt jednoczesnie w kilku sesjach (Tasks: Contentions x N)
SET NOCOUNT ON;
DECLARE @i INT = 1;
WHILE @i <= 2000
BEGIN
    CREATE TABLE #c(a INT IDENTITY, b CHAR(100));
    INSERT INTO #c(b) VALUES (REPLICATE('Z', 100));
    DROP TABLE #c;
    SET @i += 1;
END
PRINT 'Contention worker finished.';
