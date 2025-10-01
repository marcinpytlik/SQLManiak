USE GhostLabDB;
GO

-- 0) Na wszelki wypadek: pokaż co jest na stronie (1:28056)
SELECT g.Id, plc.file_id, plc.page_id, plc.slot_id
FROM dbo.GhostLab AS g
CROSS APPLY sys.fn_PhysLocCracker(%%physloc%%) AS plc
WHERE plc.file_id = 1 AND plc.page_id = 28056
ORDER BY plc.slot_id;

-- 1) Kasujemy TYLKO wiersze z tej strony, ale trzymamy transakcję otwartą
BEGIN TRAN;

DELETE g
FROM dbo.GhostLab AS g
CROSS APPLY sys.fn_PhysLocCracker(%%physloc%%) AS plc
WHERE plc.file_id = 1 AND plc.page_id = 28056;

-- (opcjonalnie) zapisz ilu skasowano
-- SELECT @@ROWCOUNT AS deleted_from_28056;

-- 2) Zobacz ghosty ZANIM wejdzie cleanup
DBCC TRACEON(3604);
DBCC PAGE (GhostLabDB, 1, 28056, 3) WITH TABLERESULTS;
-- Szukaj: m_ghostRecCnt > 0 w nagłówku + "Record Attributes: ... GHOST_REC ..." przy slotach

-- 3) Potwierdź w DMV, że ghosty istnieją
SELECT
    ips.index_id, ips.index_type_desc,
    ips.record_count,
    ips.ghost_record_count,
    ips.version_ghost_record_count,
    ips.avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.GhostLab'), 1, NULL, 'DETAILED') AS ips;

-- 4) Zatwierdź (ghosty już zostają logicznie usunięte)
COMMIT;

-- 5) (opcjonalnie) Wymuś sprzątnięcie i porównaj stronę PRZED/PO
DBCC FORCEGHOSTCLEANUP () WITH NO_INFOMSGS;

DBCC PAGE (GhostLabDB, 1, 28056, 3) WITH TABLERESULTS;
-- Teraz m_ghostRecCnt powinno spaść, a sloty-ghosty zniknąć, m_freeCnt wzrośnie.

-- 6) Snapshot po sprzątnięciu
SELECT
    ips.index_id, ips.index_type_desc,
    ips.record_count,
    ips.ghost_record_count,
    ips.version_ghost_record_count,
    ips.avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.GhostLab'), 1, NULL, 'DETAILED') AS ips;
