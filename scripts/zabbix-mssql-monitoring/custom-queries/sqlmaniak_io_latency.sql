SET NOCOUNT ON;

SELECT
    COALESCE(SUM(CONVERT(bigint, vfs.io_stall_read_ms)), 0) AS read_stall_ms_total,
    COALESCE(SUM(CONVERT(bigint, vfs.num_of_reads)), 0) AS reads_total,
    COALESCE(SUM(CONVERT(bigint, vfs.io_stall_write_ms)), 0) AS write_stall_ms_total,
    COALESCE(SUM(CONVERT(bigint, vfs.num_of_writes)), 0) AS writes_total
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs;
