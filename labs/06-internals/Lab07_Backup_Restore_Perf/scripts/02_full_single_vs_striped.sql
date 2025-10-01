-- scripts/02_full_single_vs_striped.sql
-- EDYTUJ ŚCIEŻKI!
DECLARE @b1 NVARCHAR(260) = N'C:\SQLBackups\BkpLab_full_single.bak';
DECLARE @s1 NVARCHAR(260) = N'C:\SQLBackups\BkpLab_full_stripe1.bak';
DECLARE @s2 NVARCHAR(260) = N'C:\SQLBackups\BkpLab_full_stripe2.bak';
DECLARE @s3 NVARCHAR(260) = N'C:\SQLBackups\BkpLab_full_stripe3.bak';
DECLARE @s4 NVARCHAR(260) = N'C:\SQLBackups\BkpLab_full_stripe4.bak';

-- Single (no compression)
BACKUP DATABASE BkpLab TO DISK = @b1 WITH INIT, COPY_ONLY, STATS=5, CHECKSUM, FORMAT;
GO

-- Striped (4x), compression ON
BACKUP DATABASE BkpLab TO 
DISK = N'C:\SQLBackups\BkpLab_full_s1.bak',
DISK = N'C:\SQLBackups\BkpLab_full_s2.bak',
DISK = N'C:\SQLBackups\BkpLab_full_s3.bak',
DISK = N'C:\SQLBackups\BkpLab_full_s4.bak'
WITH INIT, COPY_ONLY, STATS=5, CHECKSUM, COMPRESSION;
GO

-- Opcjonalny test parametrów buforów
BACKUP DATABASE BkpLab TO DISK = N'C:\SQLBackups\BkpLab_full_tuned.bak'
WITH INIT, COPY_ONLY, STATS=5, CHECKSUM, COMPRESSION,
     MAXTRANSFERSIZE = 4194304,  -- 4MB
     BUFFERCOUNT = 64,
     BLOCKSIZE = 65536;          -- 64KB
GO

-- Raport z msdb
SELECT TOP (20) b.database_name, b.backup_start_date, b.backup_finish_date,
       DATEDIFF(SECOND, b.backup_start_date, b.backup_finish_date) AS duration_s,
       b.type, b.compressed_backup_size/1024/1024 AS size_MB, mf.physical_device_name
FROM msdb.dbo.backupset b
JOIN msdb.dbo.backupmediafamily mf ON b.media_set_id = mf.media_set_id
WHERE b.database_name = 'BkpLab'
ORDER BY b.backup_start_date DESC;
