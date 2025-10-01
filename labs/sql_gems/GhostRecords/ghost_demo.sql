
/* Ghost Records Demo – SQL Server
   Uwaga: uruchamiaj w testowej bazie.
*/

SET NOCOUNT ON;

-- 1) Przygotowanie bazy/labu
IF DB_ID('GhostLabDB') IS NULL
BEGIN
    CREATE DATABASE GhostLabDB;
END
GO
USE GhostLabDB;
GO

IF OBJECT_ID('dbo.GhostLab','U') IS NOT NULL DROP TABLE dbo.GhostLab;
GO

CREATE TABLE dbo.GhostLab
(
    Id INT NOT NULL IDENTITY(1,1) CONSTRAINT PK_GhostLab PRIMARY KEY CLUSTERED,
    Payload CHAR(200) NOT NULL DEFAULT REPLICATE('X',200),
    Stamp DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- 2) Załaduj trochę danych
INSERT INTO dbo.GhostLab DEFAULT VALUES;
GO 10000

-- 3) Usuń część wierszy, by utworzyć ghosty
DELETE TOP (3000) FROM dbo.GhostLab WHERE Id % 3 = 0;
GO

CHECKPOINT;
GO

-- 4) DMVs – policz rekordy i ghosty
SELECT
    ips.database_id, DB_NAME(ips.database_id) AS dbname,
    OBJECT_NAME(ips.object_id, ips.database_id) AS object_name,
    ips.index_id, ips.index_type_desc,
    ips.record_count,
    ips.ghost_record_count,
    ips.version_ghost_record_count,
    ips.avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.GhostLab'), NULL, NULL, 'DETAILED') AS ips
ORDER BY index_id;

-- 5) Liczniki operacyjne (zależnie od wersji mogą się różnić kolumny)
SELECT *
FROM sys.dm_db_index_operational_stats(DB_ID(), OBJECT_ID('dbo.GhostLab'), NULL, NULL);

-- 6) Opcjonalnie: podejrzyj strony i PageLSN
--    DBCC IND listuje strony, DBCC PAGE pokazuje szczegóły (wymaga TF 3604)
DBCC IND (GhostLabDB, 'dbo.GhostLab', 1);   -- 1 = indeks klastrowany
-- Wybierz jedną stronę z powyższej listy (kolumna PagePID) i podstaw do DBCC PAGE

-- Włącz wyjście DBCC PAGE do klienta
DBCC TRACEON(3604);
GO
-- PRZYKŁAD: podstaw numer strony z wyniku DBCC IND zamiast 12345
DBCC PAGE (GhostLabDB, 1, 28056, 3) WITH TABLERESULTS;  -- 3 = pełne szczegóły

PRINT 'Ghost demo: gotowe. Użyj cleanup.sql, by wymusić sprzątnięcie ghostów.';
SELECT TOP (50)
       Id,
       sys.fn_PhysLocFormatter(%%physloc%%) AS physloc
FROM dbo.GhostLab
ORDER BY Id;

