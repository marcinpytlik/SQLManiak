-- scripts/01_setup.sql
-- Tworzy bazę i tabelę do labu Ghost Records.
USE master;
IF DB_ID(N'GhostLabDB') IS NOT NULL
BEGIN
    ALTER DATABASE GhostLabDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE GhostLabDB;
END;
GO

CREATE DATABASE GhostLabDB;
GO
ALTER DATABASE GhostLabDB SET RECOVERY SIMPLE;
GO

USE GhostLabDB;
GO

IF OBJECT_ID(N'dbo.GhostLab', 'U') IS NOT NULL
    DROP TABLE dbo.GhostLab;
GO

CREATE TABLE dbo.GhostLab
(
    Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_GhostLab_Id PRIMARY KEY CLUSTERED,
    Payload CHAR(400) NOT NULL DEFAULT REPLICATE('X', 400),
    CreatedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- Wstaw 50k rekordów (ok. ~20MB danych)
;WITH n AS
(
    SELECT TOP (50000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT dbo.GhostLab DEFAULT VALUES
OPTION (MAXDOP 1);
GO

-- Statystyki początkowe
SELECT
    ips.index_type_desc,
    ips.record_count,
    ips.ghost_record_count,
    ips.avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.GhostLab'), 1, NULL, 'DETAILED') AS ips;
GO
