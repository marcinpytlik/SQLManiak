/* Lab 02 — Shrink bez truncation – brak efektu */
USE LogLab;

/* Próba shrinka bez poprzedzającego truncation: */
DBCC SHRINKFILE (LogLab_log, 64);   -- docelowo 64 MB
SELECT total_log_size_mb, active_log_size_mb, log_truncation_holdup_reason
FROM sys.dm_db_log_stats(DB_ID());

/* Teraz truncation przez BACKUP LOG (w FULL): */
BACKUP LOG LogLab TO DISK = 'C:\Temp\LogLab_log1.trn' WITH INIT, COMPRESSION;

/* I dopiero shrink: */
DBCC SHRINKFILE (LogLab_log, 64);

SELECT total_log_size_mb, active_log_size_mb, log_truncation_holdup_reason
FROM sys.dm_db_log_stats(DB_ID());
