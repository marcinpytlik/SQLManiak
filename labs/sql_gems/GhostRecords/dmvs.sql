
/* DMVs snapshot – GhostLabDB */
USE GhostLabDB;
GO

SELECT
    GETDATE() AS captured_at,
    ips.index_id,
    ips.index_type_desc,
    ips.record_count,
    ips.ghost_record_count,
    ips.version_ghost_record_count,
    ips.avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.GhostLab'), NULL, NULL, 'SAMPLED') AS ips
ORDER BY ips.index_id;

SELECT GETDATE() AS captured_at, *
FROM sys.dm_db_index_operational_stats(DB_ID(), OBJECT_ID('dbo.GhostLab'), NULL, NULL);
