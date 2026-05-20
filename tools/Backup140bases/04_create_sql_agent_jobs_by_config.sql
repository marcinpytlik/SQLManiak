USE [msdb];
GO

DECLARE @JobName sysname;

DECLARE managed_jobs CURSOR LOCAL FAST_FORWARD FOR
    SELECT JobName
    FROM (VALUES
        (N'DBA_Backup_FULL_Configured_Databases'),
        (N'DBA_Backup_DIFF_Configured_Databases'),
        (N'DBA_Backup_LOG_Configured_Databases')
    ) AS j(JobName);

OPEN managed_jobs;
FETCH NEXT FROM managed_jobs INTO @JobName;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
    BEGIN
        EXEC msdb.dbo.sp_delete_job
            @job_name = @JobName,
            @delete_unused_schedule = 1;
    END;

    FETCH NEXT FROM managed_jobs INTO @JobName;
END;

CLOSE managed_jobs;
DEALLOCATE managed_jobs;
GO

DECLARE @JobIdFull uniqueidentifier;

EXEC msdb.dbo.sp_add_job
    @job_name = N'DBA_Backup_FULL_Configured_Databases',
    @enabled = 1,
    @description = N'FULL backup baz skonfigurowanych w msdb.dbo.DBA_BackupDatabaseConfig.',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa',
    @job_id = @JobIdFull OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobIdFull,
    @step_name = N'FULL backup configured databases',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'EXEC dbo.usp_BackupDatabases_ByConfig @BackupType = ''FULL'';',
    @retry_attempts = 1,
    @retry_interval = 5;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Daily configured databases FULL at 20:00',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 200000;

EXEC msdb.dbo.sp_attach_schedule
    @job_id = @JobIdFull,
    @schedule_name = N'Daily configured databases FULL at 20:00';

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @JobIdFull,
    @server_name = N'(LOCAL)';
GO

DECLARE @JobIdDiff uniqueidentifier;

EXEC msdb.dbo.sp_add_job
    @job_name = N'DBA_Backup_DIFF_Configured_Databases',
    @enabled = 1,
    @description = N'DIFF backup baz skonfigurowanych w msdb.dbo.DBA_BackupDatabaseConfig. Bazy systemowe są pomijane.',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa',
    @job_id = @JobIdDiff OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobIdDiff,
    @step_name = N'DIFF backup configured databases',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'EXEC dbo.usp_BackupDatabases_ByConfig @BackupType = ''DIFF'';',
    @retry_attempts = 1,
    @retry_interval = 5;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Configured databases DIFF every 3 hours',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 8,
    @freq_subday_interval = 3,
    @active_start_time = 060000,
    @active_end_time = 235959;

EXEC msdb.dbo.sp_attach_schedule
    @job_id = @JobIdDiff,
    @schedule_name = N'Configured databases DIFF every 3 hours';

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @JobIdDiff,
    @server_name = N'(LOCAL)';
GO

DECLARE @JobIdLog uniqueidentifier;

EXEC msdb.dbo.sp_add_job
    @job_name = N'DBA_Backup_LOG_Configured_Databases',
    @enabled = 1,
    @description = N'LOG backup baz skonfigurowanych w msdb.dbo.DBA_BackupDatabaseConfig. Bazy SIMPLE są pomijane.',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa',
    @job_id = @JobIdLog OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobIdLog,
    @step_name = N'LOG backup configured databases',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'EXEC dbo.usp_BackupDatabases_ByConfig @BackupType = ''LOG'';',
    @retry_attempts = 1,
    @retry_interval = 5;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Configured databases LOG every 10 minutes',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 10,
    @active_start_time = 000000,
    @active_end_time = 235959;

EXEC msdb.dbo.sp_attach_schedule
    @job_id = @JobIdLog,
    @schedule_name = N'Configured databases LOG every 10 minutes';

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @JobIdLog,
    @server_name = N'(LOCAL)';
GO
