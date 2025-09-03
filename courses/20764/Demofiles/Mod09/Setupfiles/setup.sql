USE master;

IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'AdventureWorks')
BEGIN
	DROP DATABASE AdventureWorks
END
GO

IF EXISTS (SELECT * FROM sys.databases WHERE name = 'AdminDB')
  DROP DATABASE AdminDB;
GO

CREATE DATABASE AdminDB
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'AdminDB', FILENAME = N'$(SUBDIR)SetupFiles\AdminDB.mdf' , SIZE = 16384KB , MAXSIZE = UNLIMITED, FILEGROWTH = 16384KB )
 LOG ON 
( NAME = N'AdminDB_Log', FILENAME = N'$(SUBDIR)SetupFiles\AdminDB_log.ldf' , SIZE = 1536KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
GO
GO

USE msdb;
IF EXISTS (SELECT * FROM dbo.sysjobs where name = N'Record Execution Identity')
	EXEC msdb.dbo.sp_delete_job @job_name=N'Record Execution Identity', @delete_unused_schedule=1
GO

IF EXISTS (SELECT * FROM dbo.sysjobs where name = N'Copy Export File')
	EXEC msdb.dbo.sp_delete_job @job_name=N'Copy Export File', @delete_unused_schedule=1
GO

USE master;
IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'ITSupportLogin')
	DROP LOGIN ITSupportLogin
GO

CREATE LOGIN ITSupportLogin WITH PASSWORD='Pa$$w0rd', CHECK_EXPIRATION=OFF, CHECK_POLICY=ON;
GO

USE AdminDB;
GO

CREATE USER ITSupport FOR LOGIN ITSupportLogin;
GO

CREATE TABLE dbo.IdentityLog
( IdentityLogID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
  LogEntryDatetime datetime2 NOT NULL DEFAULT SYSDATETIME(),
  RunAsIdentity sysname NOT NULL
); 
GO

CREATE PROCEDURE dbo.RecordIdentity
AS
INSERT INTO dbo.IdentityLog (RunAsIdentity)
SELECT system_user;
GO

USE [msdb]
GO



/****** Object:  Job [Record Execution Identity]    Script Date: 4/18/2016 2:45:34 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/18/2016 2:45:34 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Record Execution Identity', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'ADVENTUREWORKS\Student', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Execute dbo.RecordIdentity]    Script Date: 4/18/2016 2:45:34 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute dbo.RecordIdentity', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC dbo.RecordIdentity;', 
		@database_name=N'AdminDB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

USE msdb
GO
IF EXISTS (SELECT * FROM msdb.dbo.sysproxies WHERE name = N'FileOp')
	EXEC sp_delete_proxy @proxy_name = N'FileOp';

USE master
GO
IF EXISTS (SELECT * FROM sys.credentials WHERE name = 'FileOperation')
	DROP CREDENTIAL FileOperation;
GO

