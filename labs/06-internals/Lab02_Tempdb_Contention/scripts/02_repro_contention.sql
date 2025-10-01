-- scripts/02_repro_contention.sql
-- Uruchom ten skrypt W KILKU SESJACH równolegle (np. 4–8).
USE tempdb;
GO
SET NOCOUNT ON;
DECLARE @i int = 0;

WHILE (@i < 5000)
BEGIN
    -- mała tablica tymczasowa z heapem
    CREATE TABLE #t (a INT NOT NULL, b CHAR(200) NOT NULL DEFAULT REPLICATE('X',200));
    INSERT INTO #t(a) SELECT TOP (100) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM sys.all_objects;
    DELETE TOP (50) FROM #t; -- generuje prace na PFS/SGAM/IAM
    DROP TABLE #t;
    SET @i += 1;
END
