:setvar FilePattern "D:\SQLAudit\Audit_PermChanges_*.sqlaudit"

/* Job: Audit – Archive From Files */
USE msdb;
GO

DECLARE @job_id uniqueidentifier;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Audit – Archive From Files')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = N'Audit – Archive From Files', @delete_unused_schedule=1;
END
GO

EXEC msdb.dbo.sp_add_job
    @job_name = N'Audit – Archive From Files',
    @enabled = 1,
    @description = N'Importuje nowe zdarzenia z plików .sqlaudit do AuditDB.dbo.AuditEvents',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa',
    @job_id = @job_id OUTPUT;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'Audit – Archive From Files',
    @step_name = N'Import from files',
    @subsystem = N'TSQL',
    @database_name = N'AuditDB',
    @command = N'EXEC dbo.usp_ImportAuditFromFiles @FilePattern = N''$(FilePattern)'';',
    @retry_attempts = 3,
    @retry_interval = 2;
GO

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Every 5 minutes',
    @freq_type = 4,             -- daily
    @freq_interval = 1,
    @freq_subday_type = 4,      -- minutes
    @freq_subday_interval = 5,
    @active_start_time = 000000;
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'Audit – Archive From Files',
    @schedule_name = N'Every 5 minutes';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'Audit – Archive From Files';
GO
