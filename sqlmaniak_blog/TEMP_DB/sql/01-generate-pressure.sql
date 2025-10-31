
-- 01-generate-pressure.sql
-- Kontrolowany stres TempDB: #temp + sort + hashe
-- Reguluj intensywnosc parametrami:
DECLARE @Loops INT = 2000;   -- liczba iteracji
DECLARE @Rows  INT = 2000;   -- rozmiar tymczasowej tabeli

SET NOCOUNT ON;

WHILE @Loops > 0
BEGIN
    CREATE TABLE #t (id INT IDENTITY(1,1), c1 INT, c2 CHAR(4000));
    INSERT INTO #t(c1, c2)
    SELECT TOP (@Rows) ABS(CHECKSUM(NEWID())), REPLICATE('X', 4000)
    FROM sys.all_objects a CROSS JOIN sys.all_objects b;

    -- Sort + hash (miejsce w tempdb)
    SELECT TOP 10 c1, COUNT(*) cnt
    FROM #t
    GROUP BY c1
    ORDER BY cnt DESC;

    DROP TABLE #t;
    SET @Loops -= 1;
END
PRINT 'Pressure done.';
