
/* Job: Audit – Healthcheck */
USE msdb;
GO

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Audit – Healthcheck')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = N'Audit – Healthcheck', @delete_unused_schedule=1;
END
GO

EXEC msdb.dbo.sp_add_job
    @job_name = N'Audit – Healthcheck',
    @enabled = 1,
    @description = N'Sprawdza, czy audyty są ON oraz czy w plikach pojawiają się nowe wpisy',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO

/* Krok 1: stan audytów na ON */
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'Audit – Healthcheck',
    @step_name = N'Check server audits state',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
IF EXISTS (
    SELECT 1
    FROM sys.server_audits
    WHERE is_state_enabled = 0
)
BEGIN
    RAISERROR(''Some SERVER AUDITS are OFF'', 16, 1);
END
';

/* Krok 2: świeżość wpisów – ostatnie 24h w plikach */
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'Audit – Healthcheck',
    @step_name = N'Check recent events (24h)',
    @subsystem = N'TSQL',
    @database_name = N'AuditDB',
    @command = N'
IF NOT EXISTS (
    SELECT 1
    FROM dbo.AuditEvents
    WHERE event_time >= DATEADD(hour, -24, SYSDATETIME())
)
BEGIN
    RAISERROR(''No recent audit events in last 24h (check pipeline)'', 16, 1);
END
',
    @on_success_action = 1,   -- go to next step / quit
    @on_fail_action = 2;      -- quit with failure
GO

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Hourly',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 8,  -- hours
    @freq_subday_interval = 1,
    @active_start_time = 000000;
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'Audit – Healthcheck',
    @schedule_name = N'Hourly';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'Audit – Healthcheck';
GO
