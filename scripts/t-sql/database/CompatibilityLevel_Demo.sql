/*=====================================================================
  File:        CompatibilityLevel_Demo.sql
  Purpose:     Demo to compare SQL Server Query Optimizer behavior under
               different database compatibility levels (130 vs 160).
  Author:      marcin / prepared by assistant
  Requirements:
    - SQL Server 2016+
    - Permissions: ALTER DATABASE
=====================================================================*/

/*=====================================================================
  0) Preparation: Create demo database
=====================================================================*/
IF DB_ID('CompatLevelDemo') IS NOT NULL
    DROP DATABASE CompatLevelDemo;
GO

CREATE DATABASE CompatLevelDemo;
GO

USE CompatLevelDemo;
GO

/*=====================================================================
  1) Table with skewed data distribution
=====================================================================*/
IF OBJECT_ID('dbo.SkewedData') IS NOT NULL DROP TABLE dbo.SkewedData;
GO

CREATE TABLE dbo.SkewedData
(
    id INT IDENTITY(1,1) PRIMARY KEY,
    Category CHAR(1) NOT NULL,
    filler CHAR(200) NOT NULL DEFAULT REPLICATE('X',200)
);
GO

-- Insert skewed distribution: 90% 'A', 10% 'B'
INSERT INTO dbo.SkewedData (Category)
SELECT TOP (100000) 
       CASE WHEN (ROW_NUMBER() OVER (ORDER BY (SELECT NULL))) % 10 = 0 
            THEN 'B' ELSE 'A' END
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO

CREATE INDEX IX_SkewedData_Category ON dbo.SkewedData(Category);
GO

/*=====================================================================
  2) Parameter Sensitive Plan (PSP) behavior demo
=====================================================================*/
DECLARE @Category CHAR(1);

-- Typical query with parameter
SET @Category = 'A';   -- common value
SELECT COUNT(*) 
FROM dbo.SkewedData
WHERE Category = @Category;
GO

SET @Category = 'B';   -- rare value
SELECT COUNT(*) 
FROM dbo.SkewedData
WHERE Category = @Category;
GO

/*=====================================================================
  3) Switch compatibility level to test optimizer behavior
=====================================================================*/
-- Set to 130 (SQL Server 2016)
ALTER DATABASE CompatLevelDemo SET COMPATIBILITY_LEVEL = 130;
GO

-- Rerun queries here and observe plans (Query Store or Actual Plans)

-- Set to 160 (SQL Server 2022)
ALTER DATABASE CompatLevelDemo SET COMPATIBILITY_LEVEL = 160;
GO

-- Rerun queries and compare behavior

/*=====================================================================
  4) Cleanup
=====================================================================*/
-- DROP DATABASE CompatLevelDemo;
