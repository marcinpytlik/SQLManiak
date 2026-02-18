/* tempdb health:
   - top sessions using tempdb (current allocations)
   - version store usage (if enabled) and top version store consumers
*/
SET NOCOUNT ON;

-- Top sessions by tempdb usage (current)
SELECT TOP (30)
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    (su.user_objects_alloc_page_count + su.internal_objects_alloc_page_count) * 8.0 / 1024 AS AllocatedMB,
    (su.user_objects_dealloc_page_count + su.internal_objects_dealloc_page_count) * 8.0 / 1024 AS DeallocatedMB
FROM sys.dm_db_session_space_usage su
JOIN sys.dm_exec_sessions s ON s.session_id = su.session_id
WHERE s.is_user_process = 1
ORDER BY AllocatedMB DESC;

PRINT '---';

-- Version store (db_id=2 for tempdb)
SELECT
    SUM(version_store_reserved_page_count) * 8.0 / 1024 AS VersionStoreMB,
    SUM(user_object_reserved_page_count) * 8.0 / 1024 AS UserObjectsMB,
    SUM(internal_object_reserved_page_count) * 8.0 / 1024 AS InternalObjectsMB,
    SUM(unallocated_extent_page_count) * 8.0 / 1024 AS FreeSpaceMB
FROM sys.dm_db_file_space_usage;

PRINT '---';

-- Top version store consumers (transactions)
SELECT TOP (30)
    at.transaction_id,
    at.transaction_begin_time,
    at.transaction_type,
    at.transaction_state,
    st.session_id,
    es.login_name,
    es.host_name,
    es.program_name,
    dt.database_transaction_log_record_count,
    dt.database_transaction_log_bytes_used
FROM sys.dm_tran_active_transactions at
JOIN sys.dm_tran_session_transactions st ON st.transaction_id = at.transaction_id
JOIN sys.dm_exec_sessions es ON es.session_id = st.session_id
LEFT JOIN sys.dm_tran_database_transactions dt
  ON dt.transaction_id = at.transaction_id
WHERE es.is_user_process = 1
ORDER BY at.transaction_begin_time;
