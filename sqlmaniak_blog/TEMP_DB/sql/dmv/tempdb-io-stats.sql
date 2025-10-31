
-- dmv/tempdb-io-stats.sql
SELECT database_id, file_id, num_of_writes, num_of_reads, io_stall_read_ms, io_stall_write_ms
FROM sys.dm_io_virtual_file_stats(DB_ID('tempdb'), NULL);
