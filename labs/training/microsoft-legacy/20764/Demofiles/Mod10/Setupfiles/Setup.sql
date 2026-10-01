USE master
GO

-- Drop and restore AdventureWorks database
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'AdventureWorks')
BEGIN
	DROP DATABASE AdventureWorks
END
GO

RESTORE DATABASE [AdventureWorks] FROM  DISK = N'D:\SetupFiles\AdventureWorks.bak' WITH  REPLACE,
MOVE N'AdventureWorks' TO N'$(SUBDIR)SetupFiles\AdventureWorks.mdf', 
MOVE N'AdventureWorks_Log' TO N'$(SUBDIR)SetupFiles\AdventureWorks_log.ldf'
GO
ALTER AUTHORIZATION ON DATABASE::AdventureWorks TO [AdventureWorks\Student];
GO

EXEC  msdb.dbo.sp_delete_database_backuphistory @database_name = 'AdventureWorks';
GO


--Reset multi-server jobs
EXECUTE msdb.dbo.sp_delete_targetserver @server_name = 'MIA-SQL\SQL2';

IF EXISTS (select * from msdb.dbo.sysjobs WHERE name = N'Backup master database')
EXEC msdb.dbo.sp_delete_job @job_name=N'Backup master database', @delete_unused_schedule=1
GO

IF EXISTS (select * from msdb.dbo.sysjobs WHERE name = N'Back Up Database - AdventureWorks')
EXEC msdb.dbo.sp_delete_job @job_name=N'Back Up Database - AdventureWorks', @delete_unused_schedule=1
GO

-- Delete Log Full Alert
EXEC msdb.dbo.sp_delete_alert @name=N'Log Full Alert'
GO

EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator=N'', 
		@notificationmethod=0
GO

-- Delete Student operator
EXEC msdb.dbo.sp_delete_operator @name=N'Student'
GO

-- Delete Database Mail account and profile
EXEC msdb.dbo.sp_set_sqlagent_properties @email_profile=N'', 
		@email_save_in_sent_folder=1, 
		@databasemail_profile=N''
GO

EXECUTE msdb.dbo.sysmail_delete_account_sp    @account_name = 'AdventureWorks Administrator' ;
EXECUTE msdb.dbo.sysmail_delete_profile_sp    @profile_name = 'SQL Server Agent Profile' ;
GO


USE [msdb]
GO
DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'Back Up Database - AdventureWorks', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'ADVENTUREWORKS\Student', @job_id = @jobId OUTPUT
select @jobId
GO

EXEC msdb.dbo.sp_add_jobserver @job_name=N'Back Up Database - AdventureWorks', @server_name = N'MIA-SQL'
GO

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Back Up Database - AdventureWorks', @step_name=N'1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'BACKUP DATABASE [AdventureWorks] TO  DISK = N''$(SUBDIR)AdventureWorks.bak'' WITH NOFORMAT, NOINIT,  NAME = N''AdventureWorks-Full Database Backup'', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO
', 
		@database_name=N'master', 
		@flags=0
GO

EXEC msdb.dbo.sp_update_job @job_name=N'Back Up Database - AdventureWorks', 
		@enabled=1, 
		@start_step_id=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'ADVENTUREWORKS\Student', 
		@notify_email_operator_name=N'', 
		@notify_netsend_operator_name=N'', 
		@notify_page_operator_name=N''
GO



-- Create a database with a fixed log file
IF EXISTS(SELECT * FROM sys.databases WHERE name = 'TestAlertDB') 
  DROP DATABASE TestAlertDB;
GO
CREATE DATABASE TestAlertDB
ON
  PRIMARY ( NAME = N'TestAlertDB',
  FILENAME = N'$(SUBDIR)SetupFiles\TestAlertDB.mdf',
  SIZE = 10240KB ,
  FILEGROWTH = 1024KB )
  LOG ON ( NAME = N'TestAlertDB_log',
   FILENAME = N'$(SUBDIR)SetupFiles\TestAlertDB_log.ldf',
   SIZE = 20480KB , FILEGROWTH = 0);
GO
   
ALTER DATABASE TestAlertDB SET RECOVERY FULL;
GO

CREATE TABLE TestAlertDB.dbo.testtable
(
 id int identity(1,1) PRIMARY KEY,
 col1 char(2000)
);
GO

BACKUP DATABASE TestAlertDB
TO DISK = N'$(SUBDIR)SetupFiles\TestAlertDB_full.bak'
WITH INIT;
GO