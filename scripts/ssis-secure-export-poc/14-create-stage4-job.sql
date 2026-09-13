/*
    POC: Secure export without unconstrained delegation
    Stage 4 - SQL Agent CmdExec job executed through dedicated Proxy
*/

USE [msdb];
GO

SET NOCOUNT ON;

DECLARE @JobName sysname = N'POC_Secure_Export_Stage4';
DECLARE @ProxyName sysname = N'POC_Export_CmdExec_Proxy';
DECLARE @OutputShare nvarchar(4000) = N'\\DC01\SSISLab$';
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
    THROW 57001, 'Required SQL Agent CmdExec proxy was not found or is disabled.', 1;
END;

SELECT @CmdExecSubsystemId = subsystem_id
FROM dbo.syssubsystems
WHERE subsystem = N'CmdExec';

IF @CmdExecSubsystemId IS NULL
BEGIN
    THROW 57002, 'SQL Agent CmdExec subsystem was not found.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.sysproxysubsystem
    WHERE proxy_id = @ProxyId
      AND subsystem_id = @CmdExecSubsystemId
)
BEGIN
    THROW 57003, 'POC CmdExec proxy is not granted to the CmdExec subsystem.', 1;
END;

/*
    The job step launches Windows PowerShell under the Proxy identity.
    No credentials are embedded in the command. SMB authentication is performed
    directly by SQLLAB\poc-ssis-export using the Credential behind the Proxy.
*/
SET @Command =
    N'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "'
  + N'$ErrorActionPreference = ''Stop''; '
  + N'$share = ''' + REPLACE(@OutputShare, '''', '''''') + N'''; '
  + N'$file = Join-Path -Path $share -ChildPath (''cmdexec-proxy-test-{0}.txt'' -f (Get-Date -Format ''yyyyMMdd-HHmmss-fff'')); '
  + N'$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; '
  + N'$content = @(''POC Secure Export - Stage 4 CmdExec'', '
  + N'(''Timestamp={0}'' -f (Get-Date -Format ''o'')), '
  + N'(''MachineName={0}'' -f $env:COMPUTERNAME), '
  + N'(''WindowsIdentity={0}'' -f $identity), '
  + N'(''OutputFile={0}'' -f $file)); '
  + N'$content | Set-Content -LiteralPath $file -Encoding UTF8; '
  + N'if (-not (Test-Path -LiteralPath $file)) { throw ''Output file was not created.'' }; '
  + N'Write-Output (''Created: {0}'' -f $file); '
  + N'Write-Output (''WindowsIdentity: {0}'' -f $identity)"';

IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = @JobName)
BEGIN
    EXEC dbo.sp_delete_job
         @job_name = @JobName,
         @delete_unused_schedule = 1;
END;

EXEC dbo.sp_add_job
     @job_name = @JobName,
     @enabled = 1,
     @description = N'POC Stage 4 - execute PowerShell through dedicated CmdExec Proxy and write to SMB share.',
     @owner_login_name = N'sa',
     @job_id = @JobId OUTPUT;

EXEC dbo.sp_add_jobstep
     @job_id = @JobId,
     @step_name = N'Write SMB test file through CmdExec Proxy',
     @subsystem = N'CmdExec',
     @command = @Command,
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
    c.credential_identity,
    js.command
FROM dbo.sysjobs AS j
JOIN dbo.sysjobsteps AS js
    ON js.job_id = j.job_id
LEFT JOIN dbo.sysproxies AS p
    ON p.proxy_id = js.proxy_id
LEFT JOIN master.sys.credentials AS c
    ON c.credential_id = p.credential_id
WHERE j.job_id = @JobId;
GO
