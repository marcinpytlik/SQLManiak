USE [msdb];
GO

EXEC dbo.usp_BackupDatabases_ByConfig
    @BackupType = 'FULL',
    @DryRun = 1;
GO

-- Test jednej bazy - podmień nazwę:
-- EXEC dbo.usp_BackupDatabases_ByConfig @BackupType = 'FULL', @DatabaseName = N'baza1';
-- GO

SELECT
    c.DatabaseName,
    d.state_desc,
    d.recovery_model_desc,
    c.BackupBasePath,
    c.IsEnabled,
    c.BackupFull,
    c.BackupDiff,
    c.BackupLog,
    c.Priority,
    c.UpdatedAt
FROM dbo.DBA_BackupDatabaseConfig AS c
LEFT JOIN sys.databases AS d
    ON d.name = c.DatabaseName
ORDER BY c.Priority, c.DatabaseName;
GO

SELECT
    d.name,
    d.recovery_model_desc,
    d.state_desc
FROM sys.databases AS d
WHERE
    d.state_desc = 'ONLINE'
    AND d.is_read_only = 0
    AND d.name <> N'tempdb'
    AND NOT EXISTS
    (
        SELECT 1
        FROM dbo.DBA_BackupDatabaseConfig AS c
        WHERE c.DatabaseName = d.name
    )
ORDER BY d.name;
GO

SELECT TOP (200)
    LogId,
    ExecutionId,
    DatabaseName,
    BackupType,
    BackupBasePath,
    BackupFile,
    StartedAt,
    FinishedAt,
    Status,
    Message
FROM dbo.DBA_BackupExecutionLog
ORDER BY LogId DESC;
GO

SELECT
    j.name AS job_name,
    j.enabled,
    s.name AS schedule_name,
    s.enabled AS schedule_enabled,
    s.freq_type,
    s.freq_subday_type,
    s.freq_subday_interval,
    s.active_start_time,
    s.active_end_time
FROM msdb.dbo.sysjobs AS j
LEFT JOIN msdb.dbo.sysjobschedules AS js
    ON j.job_id = js.job_id
LEFT JOIN msdb.dbo.sysschedules AS s
    ON js.schedule_id = s.schedule_id
WHERE j.name LIKE N'DBA_Backup_%_Configured_Databases'
ORDER BY j.name;
GO

SELECT TOP (200)
    bs.database_name,
    CASE bs.type
        WHEN 'D' THEN 'FULL'
        WHEN 'I' THEN 'DIFF'
        WHEN 'L' THEN 'LOG'
    END AS backup_type,
    bs.backup_start_date,
    bs.backup_finish_date,
    CAST(bs.backup_size / 1024.0 / 1024.0 AS decimal(18,2)) AS backup_size_mb,
    bmf.physical_device_name
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS bmf
    ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name <> 'tempdb'
ORDER BY bs.backup_finish_date DESC;
GO
