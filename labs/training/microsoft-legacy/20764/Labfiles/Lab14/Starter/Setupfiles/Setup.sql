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

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'PromoteApp')
	DROP LOGIN [PromoteApp]
GO

CREATE LOGIN PromoteApp WITH PASSWORD = 'Pa$$w0rd', CHECK_EXPIRATION=OFF, CHECK_POLICY=ON;
GO

ALTER LOGIN PromoteApp DISABLE
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

CREATE LOGIN [ADVENTUREWORKS\AnthonyFrizzell] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]
GO

RESTORE DATABASE [AdventureWorks] FROM  DISK = N'D:\SetupFiles\AdventureWorks.bak' WITH  REPLACE,
MOVE N'AdventureWorks' TO N'$(SUBDIR)SetupFiles\AdventureWorks.mdf', 
MOVE N'AdventureWorks_Log' TO N'$(SUBDIR)SetupFiles\AdventureWorks_log.ldf'
GO
ALTER AUTHORIZATION ON DATABASE::AdventureWorks TO [AdventureWorks\Student];
GO

EXEC  msdb.dbo.sp_delete_database_backuphistory @database_name = 'AdventureWorks';
GO

USE InternetSales;
GO


CREATE PROC dbo.usp_GenerateFileList
AS
	SELECT TOP 20 CONCAT('X:\Files\ToProcess\',TABLE_NAME,'_',ABS(CHECKSUM(NEWID())) % 1000)
	FROM InternetSales.INFORMATION_SCHEMA.TABLES
	ORDER BY NEWID();
GO

USE [msdb]
GO

IF EXISTS (SELECT * FROM sysjobs WHERE name = N'Generate File List')
	EXEC msdb.dbo.sp_delete_job @job_name =N'Generate File List', @delete_unused_schedule=1
GO

 
/****** Object:  Job [Generate File List]    Script Date: 4/14/2016 8:41:38 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/14/2016 8:41:38 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Generate File List', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Execute Procedure]    Script Date: 4/14/2016 8:41:38 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute Procedure', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXECUTE dbo.usp_GenerateFileLists
GO', 
		@database_name=N'InternetSales', 
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
