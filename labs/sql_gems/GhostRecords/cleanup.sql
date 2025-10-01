
/* Cleanup ghost records */
USE GhostLabDB;
GO

-- Wymuś sprzątnięcie ghostów w bieżącej bazie
DBCC FORCEGHOSTCLEANUP (DB_ID()) WITH NO_INFOMSGS;

-- Alternatywnie: reorganizacja indeksu (również usuwa ghosty)
-- ALTER INDEX PK_GhostLab ON dbo.GhostLab REORGANIZE;

-- Snapshot po sprzątnięciu
SELECT
    GETDATE() AS captured_at,
    ips.index_id,
    ips.index_type_desc,
    ips.record_count,
    ips.ghost_record_count,
    ips.version_ghost_record_count,
    ips.avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.GhostLab'), NULL, NULL, 'DETAILED') AS ips
ORDER BY ips.index_id;
