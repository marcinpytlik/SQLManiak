
PRINT '--- Lab 4: Interleaved Execution (MSTVF) ---';
SET NOCOUNT ON;
USE AQP_Lab;

IF OBJECT_ID('dbo.ufn_TopIds','IF') IS NOT NULL DROP FUNCTION dbo.ufn_TopIds;
GO
CREATE FUNCTION dbo.ufn_TopIds(@top int)
RETURNS @t TABLE (id int NOT NULL)
AS
BEGIN
  DECLARE @i int=1;
  WHILE @i<=@top
  BEGIN
    INSERT @t VALUES (@i);
    SET @i+=1;
  END
  RETURN;
END
GO

-- Podczas kompilacji silnik "przeplata" wykonywanie TVF, by poznać realną kardynalność.
SELECT s.*
FROM dbo.Skew s
JOIN dbo.ufn_TopIds(5000) f ON f.id = s.id;
