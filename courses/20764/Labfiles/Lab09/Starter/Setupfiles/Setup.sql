USE master
GO

-- Drop unwanted databases

IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'ContainedDB')
BEGIN
	DROP DATABASE ContainedDB
END
GO

IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'InternetSales')
BEGIN
	DROP DATABASE InternetSales
END
GO

RESTORE DATABASE InternetSales FROM  DISK = N'D:\SetupFiles\internetsales.bak' WITH  REPLACE,
MOVE N'InternetSales' TO N'$(SUBDIR)SetupFiles\internetsales.mdf', 
MOVE N'InternetSales_Log' TO N'$(SUBDIR)SetupFiles\internetsales.ldf'
GO
ALTER AUTHORIZATION ON DATABASE::InternetSales TO [AdventureWorks\Student];
GO

EXEC  msdb.dbo.sp_delete_database_backuphistory @database_name = 'InternetSales';
GO

-- Drop and restore AdventureWorks database
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'AdventureWorks')
BEGIN
	DROP DATABASE AdventureWorks
END
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'SalesSupport')
	DROP LOGIN [SalesSupport]
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'ADVENTUREWORKS\WebApplicationSvc')
	DROP LOGIN [ADVENTUREWORKS\WebApplicationSvc]
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'ADVENTUREWORKS\IT_Support')
	DROP LOGIN [ADVENTUREWORKS\IT_Support]
GO

USE msdb
GO


IF EXISTS (SELECT * FROM sysjobs WHERE name = N'Generate Sales Log')
	EXEC msdb.dbo.sp_delete_job @job_name =N'Generate Sales Log', @delete_unused_schedule=1
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'PromoteApp09')
	DROP LOGIN [PromoteApp09]
GO

CREATE LOGIN PromoteApp09 WITH PASSWORD = 'Pa$$w0rd', CHECK_EXPIRATION=OFF, CHECK_POLICY=ON;
GO

IF EXISTS (SELECT * FROM sys.database_principals WHERE name = N'PromoteApp09')
	DROP USER PromoteApp09;
GO
CREATE USER PromoteApp09 FOR LOGIN PromoteApp09;
GO
ALTER ROLE SQLAgentUserRole ADD MEMBER PromoteApp09;
GO

USE InternetSales;
GO
CREATE USER PromoteApp09 FOR LOGIN PromoteApp09;

ALTER ROLE db_datareader ADD MEMBER PromoteApp09;
GO

USE msdb;
GO
 
/****** Object:  Job [Generate Sales Log]    Script Date: 4/19/2016 1:59:11 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/19/2016 1:59:11 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Generate Sales Log', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'PromoteApp09', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Execute Package]    Script Date: 4/19/2016 1:59:11 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute Package', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'SSIS', 
		@command=N'/FILE "\"D:\Labfiles\Lab09\Starter\Setupfiles\SalesLog.dtsx\"" /CHECKPOINTING OFF /REPORTING E',
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every 10 mins', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=10, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20160419, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'8a6afc14-bef5-4a3c-9576-3450d4b0fb0c'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

EXEC sp_start_job @job_name = N'Generate Sales Log';

IF EXISTS (SELECT * FROM msdb.dbo.sysproxies WHERE name = N'ExtractProxy')
	EXEC sp_delete_proxy @proxy_name = N'ExtractProxy';

USE master
GO

IF EXISTS (SELECT * FROM sys.credentials WHERE name = 'ExtractUser')
	DROP CREDENTIAL ExtractUser;
GO

USE [master]
GO
IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'ADVENTUREWORKS\ExtractUser')
	DROP LOGIN [ADVENTUREWORKS\ExtractUser]
GO

CREATE LOGIN [ADVENTUREWORKS\ExtractUser] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
GO
ALTER SERVER ROLE [sysadmin] ADD MEMBER [ADVENTUREWORKS\ExtractUser]
GO