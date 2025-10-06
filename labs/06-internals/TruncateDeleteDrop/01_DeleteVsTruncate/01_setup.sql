USE tempdb;
GO
IF OBJECT_ID('dbo.DemoDeleteTruncate') IS NOT NULL
    DROP TABLE dbo.DemoDeleteTruncate;
GO
CREATE TABLE dbo.DemoDeleteTruncate
(
    id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    filler CHAR(100) NOT NULL DEFAULT REPLICATE('X',100)
);
GO
;WITH cte AS (
  SELECT TOP (10000) 1 AS x
  FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.DemoDeleteTruncate DEFAULT VALUES
SELECT TOP (10000) 1 FROM cte;
GO
SELECT COUNT(*) AS RowsInserted FROM dbo.DemoDeleteTruncate;
