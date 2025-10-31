
-- dmv/tempdb-usage.sql
SELECT SUM(user_object_reserved_page_count)*8/1024.0 AS UserObj_MB,
       SUM(internal_object_reserved_page_count)*8/1024.0 AS InternalObj_MB,
       SUM(version_store_reserved_page_count)*8/1024.0 AS VersionStore_MB,
       SUM(unallocated_extent_page_count)*8/1024.0 AS Free_MB
FROM sys.dm_db_file_space_usage;

SELECT TOP 10 session_id,
       (user_objects_alloc_page_count + internal_objects_alloc_page_count)*8 AS AllocKB
FROM sys.dm_db_session_space_usage
ORDER BY AllocKB DESC;
