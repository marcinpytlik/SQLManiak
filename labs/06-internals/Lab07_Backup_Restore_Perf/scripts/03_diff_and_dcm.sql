-- scripts/03_diff_and_dcm.sql
-- Wprowadzamy zmiany (ok. 15% wierszy)
USE BkpLab;
GO
WITH c AS (
    SELECT Id FROM dbo.BigData WHERE Id % 7 = 0
)
UPDATE c SET Id = Id; -- dummy update wymuszający zapis
GO

-- Differential backup (korzysta z DCM)
BACKUP DATABASE BkpLab TO DISK = N'C:\SQLBackups\BkpLab_diff_01.bak' WITH DIFFERENTIAL, INIT, STATS=5, CHECKSUM, COMPRESSION;
GO

-- Raport z msdb (porównanie rozmiarów FULL vs DIFF)
SELECT b.backup_start_date, b.type, b.compressed_backup_size/1024/1024 AS size_MB, mf.physical_device_name
FROM msdb.dbo.backupset b
JOIN msdb.dbo.backupmediafamily mf ON b.media_set_id = mf.media_set_id
WHERE b.database_name = 'BkpLab'
ORDER BY b.backup_start_date DESC;
