-- Lista backupów i mediów w msdb (łańcuch backupów)
SELECT TOP (200)
    bs.database_name,
    bs.type AS backup_type,   -- D = FULL, I = DIFF, L = LOG
    bs.backup_start_date,
    bs.backup_finish_date,
    bs.first_lsn, bs.last_lsn, bs.database_backup_lsn, bs.checkpoint_lsn,
    bm.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bm
  ON bs.media_set_id = bm.media_set_id
WHERE bs.database_name = N'DemoDB'
ORDER BY backup_start_date DESC;
