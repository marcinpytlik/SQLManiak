-- scripts/03_cleanup.sql
-- Sprzątanie ghostów i porównanie statystyk.

USE GhostLabDB;
GO

-- A) Delikatnie: REORGANIZE (działa online, sprząta liście)
ALTER INDEX PK_GhostLab_Id ON dbo.GhostLab REORGANIZE;
GO

SELECT
    ips.index_type_desc,
    ips.record_count,
    ips.ghost_record_count,
    ips.avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.GhostLab'), 1, NULL, 'DETAILED') AS ips;
GO

-- B) Mocniej: REBUILD (pełna przebudowa drzewa)
ALTER INDEX PK_GhostLab_Id ON dbo.GhostLab REBUILD WITH (ONLINE = ON);
GO

SELECT
    ips.index_type_desc,
    ips.record_count,
    ips.ghost_record_count,
    ips.avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.GhostLab'), 1, NULL, 'DETAILED') AS ips;
GO

-- C) Sprzątanie labu (opcjonalnie)
-- USE master;
-- ALTER DATABASE GhostLabDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
-- DROP DATABASE GhostLabDB;
-- GO
