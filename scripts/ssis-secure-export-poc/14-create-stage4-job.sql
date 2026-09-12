/*
    POC: Secure SSIS Export without unconstrained delegation
    Stage 4 - SQL Agent job executing a File System SSIS package through SSIS Proxy
*/

USE [msdb];
GO

SET NOCOUNT ON;

DECLARE @JobName sysname = N'POC_SSIS_Secure_Export_Stage4';
DECLARE @ProxyName sysname = N'POC_SSIS_Export_Proxy';
DECLARE @PackagePath nvarchar(4000) = N'C:\SSIS\POC\WriteShareTest.dtsx';
DECLARE @Command nvarchar(max);
DECLARE @JobId uniqueidentifier;
DECLARE @SsisSubsystemId int;
DECLARE @ProxyId int;

SELECT @ProxyId = proxy_id
FROM dbo.sysproxies
WHERE name = @ProxyName
  AND enabled = 1;

IF @ProxyId IS NULL
BEGIN
    THROW 54001, 'Required SQL Agent SSIS proxy was not found or is disabled.', 1;
END;

SELECT @SsisSubsystemId = subsystem_id
FROM dbo.syssubsystems
WHERE subsystem = N'SSIS';

IF @SsisSubsystemId IS NULL
BEGIN
    THROW 54002, 'SQL Agent SSIS subsystem was not found.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.sysproxysubsystem
    WHERE proxy_id = @ProxyId
      AND subsystem_id = @SsisSubsystemId
)
BEGIN
    THROW 54003, 'POC proxy is not granted to the SSIS subsystem.', 1;
END;

/*
    SQL Server cannot reliably validate a local file path from T-SQL without
    enabling extra features such as xp_cmdshell. We deliberately do not enable
    anything for this POC. Verify C:\SSIS\POC\WriteShareTest.dtsx on SQL64
    before running this script.
*/

SET @Command =
      N'/FILE "' + @PackagePath + N'"'
    + N' /CHECKPOINTING OFF'
    + N' /REPORTING E';

IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = @JobName)
BEGIN
    EXEC dbo.sp_delete_job
         @job_name = @JobName,
         @delete_unused_schedule = 1;
END;

EXEC dbo.sp_add_job
     @job_name = @JobName,
     @enabled = 1,
     @description = N'POC Stage 4 - execute File System SSIS package through dedicated SSIS Proxy and write to SMB share.',
     @owner_login_name = N'sa',
     @job_id = @JobId OUTPUT;

EXEC dbo.sp_add_jobstep
     @job_id = @JobId,
     @step_name = N'Run WriteShareTest through SSIS Proxy',
     @subsystem = N'SSIS',
     @command = @Command,
     @database_name = N'master',
     @proxy_name = @ProxyName,
     @on_success_action = 1,
     @on_fail_action = 2,
     @retry_attempts = 0;

EXEC dbo.sp_add_jobserver
     @job_id = @JobId;

SELECT
    j.name AS JobName,
    js.step_id,
    js.step_name,
    js.subsystem,
    p.name AS ProxyName,
    js.command
FROM dbo.sysjobs AS j
JOIN dbo.sysjobsteps AS js
    ON js.job_id = j.job_id
LEFT JOIN dbo.sysproxies AS p
    ON p.proxy_id = js.proxy_id
WHERE j.job_id = @JobId;
GO