-- scripts/04_log_and_bcm.sql
-- Generujemy log (bulk operations) i backup LOG
USE BkpLab;
GO
-- BULK_LOGGED nie włączamy tutaj (lab trzyma FULL), ale BCM i tak ma zastosowanie dla bulk operations w BULK_LOGGED.
-- Dla symulacji zwykły workload:
INSERT dbo.BigData DEFAULT VALUES;
GO 10000

BACKUP LOG BkpLab TO DISK = N'C:\SQLBackups\BkpLab_log_01.trn' WITH INIT, STATS=5, CHECKSUM, COMPRESSION;
GO

-- Raport LOG backupów
SELECT TOP (20) b.backup_start_date, b.type, b.compressed_backup_size/1024/1024 AS size_MB, mf.physical_device_name
FROM msdb.dbo.backupset b
JOIN msdb.dbo.backupmediafamily mf ON b.media_set_id = mf.media_set_id
WHERE b.database_name = 'BkpLab' AND b.type = 'L'
ORDER BY b.backup_start_date DESC;
