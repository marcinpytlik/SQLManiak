
-- 00-inspect-tempdb.sql
-- Inwentaryzacja TempDB: pliki, rozmiary, autogrowth, usage

SET NOCOUNT ON;

SELECT DB_NAME(database_id) AS db_name, file_id, type_desc,
       size/128.0 AS size_MB,
       growth AS growth_raw,
       is_percent_growth,
       CASE WHEN is_percent_growth = 1 THEN CONCAT(growth, '%')
            ELSE CONCAT(growth/128, ' MB') END AS growth_setting,
       physical_name
FROM sys.master_files
WHERE database_id = DB_ID('tempdb')
ORDER BY file_id;

-- File space usage
SELECT SUM(user_object_reserved_page_count)*8/1024.0 AS UserObj_MB,
       SUM(internal_object_reserved_page_count)*8/1024.0 AS InternalObj_MB,
       SUM(version_store_reserved_page_count)*8/1024.0 AS VersionStore_MB,
       SUM(unallocated_extent_page_count)*8/1024.0 AS Free_MB
FROM sys.dm_db_file_space_usage;

-- Top sessions consuming TempDB
SELECT TOP 10 session_id,
       (user_objects_alloc_page_count + internal_objects_alloc_page_count)*8 AS AllocKB,
       (user_objects_dealloc_page_count + internal_objects_dealloc_page_count)*8 AS DeallocKB
FROM sys.dm_db_session_space_usage
ORDER BY AllocKB DESC;

-- IO stats for TempDB
SELECT database_id, file_id, num_of_reads, num_of_writes, io_stall_read_ms, io_stall_write_ms
FROM sys.dm_io_virtual_file_stats(DB_ID('tempdb'), NULL);
