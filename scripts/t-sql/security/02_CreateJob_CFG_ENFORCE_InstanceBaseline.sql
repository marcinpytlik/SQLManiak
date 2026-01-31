/* =============================================================================
   SQL Agent Job: CFG_ENFORCE_InstanceBaseline
   Creates a job that runs every 5 minutes:
     EXEC master.dbo.usp_EnforceInstanceConfigBaseline;

   Run after: 01_ConfigGuard_AllInOne.sql
   Requires: SQL Server Agent running, sysadmin rights.

   Notes:
     - Job is deleted/recreated (idempotent) to avoid duplicates.
     - Change @StartTimeHHMMSS if you want a different start time.
   ============================================================================= */

USE msdb;
GO

DECLARE
    @JobName        sysname = N'CFG_ENFORCE_InstanceBaseline',
    @JobDescription nvarchar(512) = N'Enforce instance configuration baseline (master.dbo.usp_EnforceInstanceConfigBaseline) and revert drift.',
    @StepName       sysname = N'Enforce baseline',
    @ScheduleName   sysname = N'Every 5 minutes',
    @DatabaseName   sysname = N'master',
    @Command        nvarchar(max) = N'EXEC master.dbo.usp_EnforceInstanceConfigBaseline;',
    @StartTimeHHMMSS int = 000500;  -- start 00:05:00

-- Delete existing job (and schedule if unused)
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
BEGIN
    EXEC msdb.dbo.sp_delete_job
        @job_name = @JobName,
        @delete_unused_schedule = 1;
END
GO

DECLARE
    @JobName        sysname = N'CFG_ENFORCE_InstanceBaseline',
    @JobDescription nvarchar(512) = N'Enforce instance configuration baseline (master.dbo.usp_EnforceInstanceConfigBaseline) and revert drift.',
    @StepName       sysname = N'Enforce baseline',
    @ScheduleName   sysname = N'Every 5 minutes',
    @DatabaseName   sysname = N'master',
    @Command        nvarchar(max) = N'EXEC master.dbo.usp_EnforceInstanceConfigBaseline;',
    @StartTimeHHMMSS int = 000500;

DECLARE @jobId uniqueidentifier;

EXEC msdb.dbo.sp_add_job
    @job_name         = @JobName,
    @enabled          = 1,
    @description      = @JobDescription,
    @category_name    = N'[Uncategorized (Local)]',
    @owner_login_name = N'sa',   -- change if you prefer another owner
    @job_id           = @jobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id            = @jobId,
    @step_name         = @StepName,
    @subsystem         = N'TSQL',
    @database_name     = @DatabaseName,
    @command           = @Command,
    @on_success_action = 1,   -- Quit with success
    @on_fail_action    = 2;   -- Quit with failure

EXEC msdb.dbo.sp_add_schedule
    @schedule_name        = @ScheduleName,
    @enabled              = 1,
    @freq_type            = 4,  -- daily
    @freq_interval        = 1,
    @freq_subday_type     = 4,  -- minutes
    @freq_subday_interval = 5,  -- every 5 minutes
    @active_start_time    = @StartTimeHHMMSS;

EXEC msdb.dbo.sp_attach_schedule
    @job_id        = @jobId,
    @schedule_name = @ScheduleName;

EXEC msdb.dbo.sp_add_jobserver
    @job_id      = @jobId,
    @server_name = N'(LOCAL)';

-- Summary
SELECT
    j.name AS JobName,
    j.enabled,
    s.step_name,
    sch.name AS ScheduleName
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobsteps s
    ON j.job_id = s.job_id
LEFT JOIN msdb.dbo.sysjobschedules js
    ON j.job_id = js.job_id
LEFT JOIN msdb.dbo.sysschedules sch
    ON js.schedule_id = sch.schedule_id
WHERE j.name = N'CFG_ENFORCE_InstanceBaseline';
GO
