/*
    POC: Secure export without unconstrained delegation
    Stage 5 - scheduled queue worker through CmdExec Proxy

    Prerequisites:
      Proxy : POC_Export_CmdExec_Proxy
      Script: C:\SSIS\POC\Stage5Worker.ps1
*/

USE [msdb];
GO

SET NOCOUNT ON;

DECLARE @JobName sysname = N'POC_Secure_Export_Stage5_Worker';
DECLARE @ProxyName sysname = N'POC_Export_CmdExec_Proxy';
DECLARE @ScheduleName sysname = N'POC_Secure_Export_Stage5_EveryMinute';
DECLARE @WorkerScript nvarchar(4000) = N'C:\SSIS\POC\Stage5Worker.ps1';
DECLARE @Command nvarchar(max);
DECLARE @JobId uniqueidentifier;
DECLARE @ProxyId int;
DECLARE @CmdExecSubsystemId int;

SELECT @ProxyId = proxy_id
FROM dbo.sysproxies
WHERE name = @ProxyName
  AND enabled = 1;

IF @ProxyId IS NULL
BEGIN
    THROW 59001, 'Required CmdExec proxy POC_Export_CmdExec_Proxy was not found or is disabled.', 1;
END;

SELECT @CmdExecSubsystemId = subsystem_id
FROM dbo.syssubsystems
WHERE subsystem = N'CmdExec';

IF @CmdExecSubsystemId IS NULL
BEGIN
    THROW 59002, 'SQL Agent CmdExec subsystem was not found.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.sysproxysubsystem
    WHERE proxy_id = @ProxyId
      AND subsystem_id = @CmdExecSubsystemId
)
BEGIN
    THROW 59003, 'POC CmdExec proxy is not granted to the CmdExec subsystem.', 1;
END;

SET @Command =
      N'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass '
    + N'-File "' + @WorkerScript + N'" '
    + N'-SqlInstance "localhost" '
    + N'-Database "SSIS_Delegation_Lab" '
    + N'-OutputShare "\\DC01\SSISLab$" '
    + N'-MaxItems 10 '
    + N'-RetryDelaySeconds 60';

IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = @JobName)
BEGIN
    EXEC dbo.sp_delete_job
         @job_name = @JobName,
         @delete_unused_schedule = 1;
END;

IF EXISTS (SELECT 1 FROM dbo.sysschedules WHERE name = @ScheduleName)
BEGIN
    EXEC dbo.sp_delete_schedule @schedule_name = @ScheduleName;
END;

EXEC dbo.sp_add_job
     @job_name = @JobName,
     @enabled = 1,
     @description = N'POC Stage 5 - dequeue export requests and process them through the dedicated CmdExec Proxy identity.',
     @owner_login_name = N'sa',
     @job_id = @JobId OUTPUT;

EXEC dbo.sp_add_jobstep
     @job_id = @JobId,
     @step_name = N'Process export queue',
     @subsystem = N'CmdExec',
     @command = @Command,
     @proxy_name = @ProxyName,
     @on_success_action = 1,
     @on_fail_action = 2,
     @retry_attempts = 0;

EXEC dbo.sp_add_schedule
     @schedule_name = @ScheduleName,
     @enabled = 1,
     @freq_type = 4,               -- daily
     @freq_interval = 1,
     @freq_subday_type = 4,        -- minutes
     @freq_subday_interval = 1,    -- every minute
     @active_start_time = 0;

EXEC dbo.sp_attach_schedule
     @job_id = @JobId,
     @schedule_name = @ScheduleName;

EXEC dbo.sp_add_jobserver
     @job_id = @JobId;

SELECT
    j.name AS JobName,
    j.enabled AS JobEnabled,
    js.step_id,
    js.step_name,
    js.subsystem,
    p.name AS ProxyName,
    c.credential_identity,
    js.command,
    s.name AS ScheduleName,
    s.enabled AS ScheduleEnabled,
    s.freq_subday_interval AS EveryNMinutes
FROM dbo.sysjobs AS j
JOIN dbo.sysjobsteps AS js
    ON js.job_id = j.job_id
LEFT JOIN dbo.sysproxies AS p
    ON p.proxy_id = js.proxy_id
LEFT JOIN master.sys.credentials AS c
    ON c.credential_id = p.credential_id
LEFT JOIN dbo.sysjobschedules AS jsch
    ON jsch.job_id = j.job_id
LEFT JOIN dbo.sysschedules AS s
    ON s.schedule_id = jsch.schedule_id
WHERE j.job_id = @JobId;
GO
