USE tempdb;
GO
IF OBJECT_ID('dbo.DemoDropTruncate') IS NOT NULL
    DROP TABLE dbo.DemoDropTruncate;
GO
CREATE TABLE dbo.DemoDropTruncate
(
    id INT IDENTITY(1,1) PRIMARY KEY,
    filler CHAR(100) NOT NULL DEFAULT REPLICATE('X',100)
);
GO
INSERT INTO dbo.DemoDropTruncate DEFAULT VALUES
GO 1000

-- TRUNCATE – dane znikają, struktura zostaje
TRUNCATE TABLE dbo.DemoDropTruncate;
GO
SELECT COUNT(*) AS RowsAfterTruncate FROM dbo.DemoDropTruncate;
GO

-- DROP – znika cała tabela
DROP TABLE dbo.DemoDropTruncate;
GO

-- To się nie powiedzie (brak obiektu):
-- SELECT COUNT(*) FROM dbo.DemoDropTruncate;
