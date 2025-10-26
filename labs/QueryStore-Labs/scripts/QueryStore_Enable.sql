USE [master];
GO
ALTER DATABASE [AdventureWorks2022]
SET QUERY_STORE = ON
(
    OPERATION_MODE = READ_WRITE,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    INTERVAL_LENGTH_MINUTES = 60,
    MAX_STORAGE_SIZE_MB = 1024
);
GO
SELECT actual_state_desc, desired_state_desc, readonly_reason
FROM sys.database_query_store_options;
