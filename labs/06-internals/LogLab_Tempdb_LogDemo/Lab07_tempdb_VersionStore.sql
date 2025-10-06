/* Lab 07 — tempdb i Version Store (snapshot/online index) */

/* Baza testowa do wersjonowania */
USE master;
IF DB_ID('SnapLab') IS NOT NULL DROP DATABASE SnapLab;
CREATE DATABASE SnapLab;
GO
ALTER DATABASE SnapLab SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

USE SnapLab;
IF OBJECT_ID('dbo.Demo','U') IS NOT NULL DROP TABLE dbo.Demo;
CREATE TABLE dbo.Demo(
    Id  INT PRIMARY KEY,
    Val CHAR(4000) NOT NULL DEFAULT REPLICATE('A',4000)
);
INSERT INTO dbo.Demo(Id)
SELECT TOP (50000) ROW_NUMBER() OVER(ORDER BY (SELECT NULL))
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

/**************  SESJA A  **************/
-- USE SnapLab;
-- SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
-- BEGIN TRAN;
-- SELECT COUNT(*) FROM dbo.Demo WITH (INDEX(0));
-- -- (opcjonalnie) WAITFOR DELAY '00:05:00';
-- -- Nie kończ transakcji

/**************  SESJA B  **************/
-- USE SnapLab;
-- Generuj zmiany = tworzą się wersje w tempdb:
UPDATE dbo.Demo SET Val = REPLICATE('B',4000) WHERE Id % 10 = 0;

-- Podejrzyj version store:
USE tempdb;
SELECT
  (version_store_reserved_page_count/128.0) AS MB_version_store,
  (user_object_reserved_page_count/128.0)    AS MB_user_objects,
  (internal_object_reserved_page_count/128.0)AS MB_internal_objects,
  (unallocated_extent_page_count/128.0)      AS MB_free
FROM sys.dm_db_file_space_usage;

-- Próba shrink w trakcie aktywnej transakcji snapshot (zwykle bez efektu):
DBCC SHRINKFILE (tempdev, 1024);

-- Po COMMIT/ROLLBACK w SESJI A:
-- CHECKPOINT;
-- DBCC SHRINKFILE (tempdev, 1024);
