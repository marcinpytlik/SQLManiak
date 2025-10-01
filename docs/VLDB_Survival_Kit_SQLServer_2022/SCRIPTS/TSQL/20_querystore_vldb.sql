/* 20_querystore_vldb.sql
Konfiguracja Query Store pod VLDB.
*/
USE VLDB;
GO
ALTER DATABASE CURRENT SET QUERY_STORE = ON;
ALTER DATABASE CURRENT SET QUERY_STORE (OPERATION_MODE = READ_WRITE);
ALTER DATABASE CURRENT SET QUERY_STORE (
    MAX_STORAGE_SIZE_MB = 20480, -- 20 GB; dostosuj
    INTERVAL_LENGTH_MINUTES = 10,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 14),
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    QUERY_CAPTURE_MODE = AUTO,
    WAIT_STATS_CAPTURE_MODE = ON
);
GO
-- Ograniczanie cap: włącz job czyszczący lub użyj poniższego na żądanie:
-- EXEC sys.sp_query_store_remove_plan @plan_id = ...;
-- EXEC sys.sp_query_store_reset_exec_stats @plan_id = ...;
