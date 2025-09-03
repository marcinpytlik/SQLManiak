--View backup history
USE AdventureWorks
GO 
SELECT 
CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server, 
msdb.dbo.backupset.database_name, 
msdb.dbo.backupset.backup_start_date, 
msdb.dbo.backupset.backup_finish_date, 
msdb.dbo.backupset.expiration_date, 
CASE msdb..backupset.type 
WHEN 'D' THEN 'Database' 
WHEN 'L' THEN 'Log' 
END AS backup_type, 
msdb.dbo.backupset.backup_size, 
msdb.dbo.backupmediafamily.logical_device_name, 
msdb.dbo.backupmediafamily.physical_device_name, 
msdb.dbo.backupset.name AS backupset_name, 
msdb.dbo.backupset.description 
FROM msdb.dbo.backupmediafamily 
INNER JOIN msdb.dbo.backupset ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id 
WHERE (CONVERT(datetime, msdb.dbo.backupset.backup_start_date, 102) >= GETDATE() - 30) 
ORDER BY 
msdb.dbo.backupset.database_name, 
msdb.dbo.backupset.backup_finish_date 
--End view backup history

--Use RESTORE HEADERONLY
RESTORE HEADERONLY 
FROM DISK = N'D:\Demofiles\Mod06\Demo\AW.bak' 
WITH NOUNLOAD;
GO
--End RESTORE HEADERONLY

--Use RESTORE FILELISTONLY
RESTORE FILELISTONLY FROM DISK = N'D:\Demofiles\Mod06\Demo\AW.bak';
GO
--End RESTORE FILELISTONLY

--Use RESTORE VERIFYONLY
RESTORE VERIFYONLY FROM DISK = N'D:\Demofiles\Mod06\Demo\AW.bak';
GO
--End RESTORE VERIFYONLY
