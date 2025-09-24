/*=====================================================================
  File:        CompatibilityLevel_TempdbAndDB_Demo.sql
  Purpose:     Show that query compilation follows the user database CL
               even when temporary objects live in tempdb.
=====================================================================*/

-- 0) Setup
IF DB_ID('MyDB') IS NULL
BEGIN
    CREATE DATABASE MyDB;
END
GO

-- For clarity, print current CLs
SELECT name, compatibility_level FROM sys.databases
WHERE name IN ('MyDB','tempdb','model','master');
GO

USE MyDB;
GO

-- 1) Set MyDB to 130 (simulate legacy app)
ALTER DATABASE MyDB SET COMPATIBILITY_LEVEL = 130;
GO

-- 2) Create temp table and run a query
CREATE TABLE #t (id INT IDENTITY(1,1) PRIMARY KEY, c CHAR(1));
INSERT INTO #t(c)
SELECT CASE WHEN (ROW_NUMBER() OVER (ORDER BY (SELECT NULL))) % 10 = 0 THEN 'B' ELSE 'A' END
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

-- Parameterized query against #temp
DECLARE @c CHAR(1) = 'A';
SELECT COUNT(*) FROM #t WHERE c = @c;
GO

-- Change parameter to rare value
DECLARE @c CHAR(1) = 'B';
SELECT COUNT(*) FROM #t WHERE c = @c;
GO

-- Observe plan choice (e.g., Scan vs Seek) under CL 130

DROP TABLE IF EXISTS #t;
GO

-- 3) Now set MyDB to 160 and repeat (PSP, batch mode on rowstore may help)
ALTER DATABASE MyDB SET COMPATIBILITY_LEVEL = 160;
GO

CREATE TABLE #t (id INT IDENTITY(1,1) PRIMARY KEY, c CHAR(1));
INSERT INTO #t(c)
SELECT CASE WHEN (ROW_NUMBER() OVER (ORDER BY (SELECT NULL))) % 10 = 0 THEN 'B' ELSE 'A' END
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

DECLARE @c CHAR(1) = 'A';
SELECT COUNT(*) FROM #t WHERE c = @c;
GO

DECLARE @c CHAR(1) = 'B';
SELECT COUNT(*) FROM #t WHERE c = @c;
GO

DROP TABLE IF EXISTS #t;
GO

-- 4) Cleanup (optional)
-- ALTER DATABASE MyDB SET COMPATIBILITY_LEVEL = 160;
-- DROP DATABASE IF EXISTS MyDB;
