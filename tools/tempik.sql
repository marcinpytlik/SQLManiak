SELECT TOP (100)
    bs.database_name,
    bs.type AS backup_type,
    CASE bs.type
        WHEN 'D' THEN 'FULL'
        WHEN 'I' THEN 'DIFF'
        WHEN 'L' THEN 'LOG'
        ELSE bs.type
    END AS backup_type_desc,
    bs.backup_start_date,
    bs.backup_finish_date,
    DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) AS duration_seconds,
    CAST(DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) / 60.0 AS DECIMAL(10,2)) AS duration_minutes,
    CAST(bs.backup_size / 1024.0 / 1024.0 AS DECIMAL(18,2)) AS backup_size_mb,
    bmf.physical_device_name
FROM msdb.dbo.backupset bs
LEFT JOIN msdb.dbo.backupmediafamily bmf
    ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = N'TwojaBaza'
ORDER BY bs.backup_start_date DESC;