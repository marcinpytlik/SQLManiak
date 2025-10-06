/* Lab 04 — SIMPLE vs FULL (checkpoint vs backup) */
USE master;
ALTER DATABASE LogLab SET RECOVERY SIMPLE;
GO
USE LogLab;
CHECKPOINT;  -- w SIMPLE truncation wykonuje checkpoint

DBCC SHRINKFILE (LogLab_log, 64);
SELECT total_log_size_mb, active_log_size_mb, log_truncation_holdup_reason
FROM sys.dm_db_log_stats(DB_ID());

/* Opcjonalnie powrót do FULL + pełna kopia (reset łańcucha logów) */
USE master;
ALTER DATABASE LogLab SET RECOVERY FULL;
GO
BACKUP DATABASE LogLab TO DISK = 'C:\Temp\LogLab_full2.bak' WITH INIT, COMPRESSION;
