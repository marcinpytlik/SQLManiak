/* Disabled central LAB job. Run on WINDOWS SQL Server Agent host ONLY.
   Operator must supply absolute paths; config/DPAPI files must belong to the
   SAME Windows identity that executes SQL Agent CmdExec (service/proxy).
   NEVER run on Linux Docker SQL Repository; no passwords in SQL job commands.
*/
USE msdb;
GO
DECLARE @JobName sysname=N'SQLManiak DHC v1.7 LAB',
 @ScheduleName sysname=N'SQLManiak DHC v1.7 LAB Every 5 Minutes',
 @PwshPath nvarchar(4000)=NULL,   -- path to pwsh.exe on Windows Agent HOST
 @ScriptPath nvarchar(4000)=NULL, -- path to 17_Invoke-DHC-Scheduled.ps1
 @ConfigPath nvarchar(4000)=NULL, -- private scheduler.json
 @Cmd nvarchar(max),@JobId uniqueidentifier;
IF CONVERT(nvarchar(30),SERVERPROPERTY('HostPlatform'))<>N'Windows'
 THROW 51060,'Only Windows SQL Server Agent is supported by this template.',1;
IF @PwshPath IS NULL OR @ScriptPath IS NULL OR @ConfigPath IS NULL
 THROW 51061,'Fill in PwshPath, ScriptPath, ConfigPath first.',1;
IF CHARINDEX('"',@PwshPath)>0 OR CHARINDEX('"',@ScriptPath)>0 OR CHARINDEX('"',@ConfigPath)>0
 THROW 51062,'Paths cannot contain quotes.',1;
IF EXISTS(SELECT 1 FROM dbo.sysjobs WHERE name=@JobName)
 THROW 51063,'Job already exists; refusing replacement.',1;
IF EXISTS(SELECT 1 FROM dbo.sysschedules WHERE name=@ScheduleName)
 THROW 51064,'Schedule name already exists; refusing replacement.',1;
SET @Cmd=N'"'+@PwshPath+N'" -NoProfile -NonInteractive -File "'+@ScriptPath+
  N'" -ConfigPath "'+@ConfigPath+N'" -Environment LAB -Execute';
BEGIN TRY
 BEGIN TRAN;
 EXEC dbo.sp_add_job @job_name=@JobName,@enabled=0,@job_id=@JobId OUTPUT,
   @description=N'Disabled 5-minute due-aware DHC scheduler; no embedded secrets.';
 EXEC dbo.sp_add_jobstep @job_id=@JobId,@step_name=N'DHC DueAware',
   @subsystem=N'CmdExec',@command=@Cmd,@on_success_action=1,@on_fail_action=2;
 EXEC dbo.sp_add_schedule @schedule_name=@ScheduleName,@enabled=1,
   @freq_type=4,@freq_interval=1,@freq_subday_type=4,
   @freq_subday_interval=5,@active_start_time=000000;
 EXEC dbo.sp_attach_schedule @job_id=@JobId,@schedule_name=@ScheduleName;
 EXEC dbo.sp_add_jobserver @job_id=@JobId;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
SELECT name,enabled FROM dbo.sysjobs WHERE job_id=@JobId;
GO
