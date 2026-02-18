/* IO latency per database file + volume free space.
   Requires VIEW SERVER STATE.
*/
SET NOCOUNT ON;

-- Per file IO latency since instance start
SELECT
    DB_NAME(vfs.database_id) AS DatabaseName,
    mf.type_desc AS FileType,
    mf.name AS LogicalName,
    mf.physical_name,
    vfs.num_of_reads,
    vfs.num_of_writes,
    vfs.io_stall_read_ms,
    vfs.io_stall_write_ms,
    CASE WHEN vfs.num_of_reads = 0 THEN NULL ELSE 1.0 * vfs.io_stall_read_ms / vfs.num_of_reads END AS AvgReadLatencyMs,
    CASE WHEN vfs.num_of_writes = 0 THEN NULL ELSE 1.0 * vfs.io_stall_write_ms / vfs.num_of_writes END AS AvgWriteLatencyMs,
    (vfs.size_on_disk_bytes/1024.0/1024.0) AS SizeOnDiskMB
FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
JOIN sys.master_files mf
  ON mf.database_id = vfs.database_id
 AND mf.file_id = vfs.file_id
ORDER BY
    (vfs.io_stall_read_ms + vfs.io_stall_write_ms) DESC;

PRINT '---';

-- Volume free space for all database files
SELECT DISTINCT
    vs.volume_mount_point,
    vs.file_system_type,
    vs.logical_volume_name,
    vs.total_bytes/1024.0/1024.0/1024.0 AS TotalGB,
    vs.available_bytes/1024.0/1024.0/1024.0 AS FreeGB,
    (100.0 * vs.available_bytes / NULLIF(vs.total_bytes,0)) AS FreePct
FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs
ORDER BY FreePct ASC;
