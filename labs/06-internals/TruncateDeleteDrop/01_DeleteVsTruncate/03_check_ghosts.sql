USE tempdb;
GO
SELECT
    ips.ghost_record_count,
    ips.record_count,
    ips.forwarded_record_count,
    ips.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.DemoDeleteTruncate'), NULL, NULL, 'DETAILED') AS ips;
GO
