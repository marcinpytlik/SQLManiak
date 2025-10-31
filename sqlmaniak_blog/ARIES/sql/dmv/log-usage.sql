
-- dmv/log-usage.sql
SELECT total_log_size_in_bytes/1024/1024 AS TotalMB,
       used_log_space_in_bytes/1024/1024 AS UsedMB,
       used_log_space_in_percent AS UsedPercent
FROM sys.dm_db_log_space_usage;
