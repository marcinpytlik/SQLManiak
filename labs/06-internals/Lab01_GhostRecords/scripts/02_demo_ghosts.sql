-- scripts/02_demo_ghosts.sql
-- Generuje ghost records i pozwala je obejrzeć w DMV oraz DBCC PAGE.

USE GhostLabDB;
GO

-- 1) Podgląd fizycznych lokalizacji wybranych wierszy (przed DELETE)
SELECT TOP (20)
    g.Id,
    plc.file_id, plc.page_id, plc.slot_id
FROM dbo.GhostLab AS g
CROSS APPLY sys.fn_PhysLocCracker(%%physloc%%) AS plc
ORDER BY plc.page_id, plc.slot_id;
GO

-- 2) Usuwamy ok. 35–40% wierszy losowo rozłożonych
;WITH sample AS
(
    SELECT Id
    FROM dbo.GhostLab
    WHERE (ABS(CHECKSUM(NEWID(), Id)) % 100) BETWEEN 0 AND 39
)
DELETE FROM sample;
GO

-- 3) Liczniki ghostów w DMV
SELECT
    ips.index_type_desc,
    ips.record_count,
    ips.ghost_record_count,
    ips.avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.GhostLab'), 1, NULL, 'DETAILED') AS ips;
GO

-- Operacyjne statystyki indeksu (od startu instancji)
SELECT
    ios.leaf_delete_count,
    ios.leaf_ghost_count,
    ios.nonleaf_delete_count,
    ios.range_scan_count,
    ios.leaf_allocation_count
FROM sys.dm_db_index_operational_stats(DB_ID(), OBJECT_ID('dbo.GhostLab'), 1, NULL) AS ios;
GO

-- 4) Wybierz kilka stron liścia, na których były operacje
--    Uwaga: PagePID poniżej wybierz z DBCC IND i podmień w DBCC PAGE.
DBCC IND('GhostLabDB', 'dbo.GhostLab', 1);
-- Skopiuj kilka wartości PagePID z kolumny PagePID i użyj w DBCC PAGE:
-- Przykład (podmień 1, 12345 na właściwe File:Page):
-- DBCC PAGE ('GhostLabDB', 1, 12345, 3) WITH TABLERESULTS;
-- Szukaj slotów ze statusem GHOST (Status Bits).

-- 5) Opcjonalnie: wyłącz background Ghost Cleanup (globalnie!) na czas testu
-- DBCC TRACEON(661, -1);
-- GO
-- Po zakończeniu KONIECZNIE:
-- DBCC TRACEOFF(661, -1);
-- GO
