USE master
GO

-- drop databases
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'HumanResources')
BEGIN
	DROP DATABASE HumanResources
END
GO

IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'InternetSales')
BEGIN
	DROP DATABASE InternetSales
END
GO

IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'AWDataWarehouse')
BEGIN
	DROP DATABASE AWDataWarehouse
END
GO


-- restore databases
RESTORE DATABASE HumanResources FROM  DISK = N'D:\SetupFiles\HumanResources.bak' WITH REPLACE,
MOVE N'HumanResources' TO N'$(SUBDIR)SetupFiles\HumanResources.mdf', 
MOVE N'HumanResources_log' TO N'$(SUBDIR)SetupFiles\HumanResources.ldf'
GO
ALTER AUTHORIZATION ON DATABASE::HumanResources TO [AdventureWorks\Student];
GO

EXEC  msdb.dbo.sp_delete_database_backuphistory @database_name = 'HumanResources';
GO


RESTORE DATABASE InternetSales FROM  DISK = N'D:\SetupFiles\InternetSales_10.bak' WITH REPLACE,
MOVE N'InternetSales' TO N'$(SUBDIR)SetupFiles\InternetSales.mdf', 
MOVE N'InternetSales_data1' TO N'$(SUBDIR)SetupFiles\InternetSales_data1.ndf',
MOVE N'InternetSales_data2' TO N'$(SUBDIR)SetupFiles\InternetSales_data2.ndf',
MOVE N'InternetSales_log' TO N'$(SUBDIR)SetupFiles\InternetSales.ldf'

GO
ALTER AUTHORIZATION ON DATABASE::InternetSales TO [AdventureWorks\Student];
GO

EXEC  msdb.dbo.sp_delete_database_backuphistory @database_name = 'InternetSales';
GO


RESTORE DATABASE AWDataWarehouse FROM  DISK = N'D:\SetupFiles\AWDataWarehouse.bak' WITH REPLACE,
MOVE N'AWDataWarehouse' TO N'$(SUBDIR)SetupFiles\AWDataWarehouse.mdf', 
MOVE N'AWDataWarehouse_archive' TO N'$(SUBDIR)SetupFiles\AWDataWarehouse_archive.ndf',
MOVE N'AWDataWarehouse_current' TO N'$(SUBDIR)SetupFiles\AWDataWarehouse_current.ndf',
MOVE N'AWDataWarehouse_log' TO N'$(SUBDIR)SetupFiles\AWDataWarehouse.ldf'
GO
GO
ALTER AUTHORIZATION ON DATABASE::AWDataWarehouse TO [AdventureWorks\Student];
GO

EXEC  msdb.dbo.sp_delete_database_backuphistory @database_name = 'AWDataWarehouse';
GO



--Reset multi-server jobs (in case students did the demo)
IF EXISTS (select * FROM msdb.dbo.systargetservers  WHERE server_name = 'MIA-SQL\SQL2')
	EXECUTE msdb.dbo.sp_delete_targetserver @server_name = 'MIA-SQL\SQL2';

IF EXISTS (select * from msdb.dbo.sysjobs WHERE name = N'Backup master database')
EXEC msdb.dbo.sp_delete_job @job_name=N'Backup master database', @delete_unused_schedule=1
GO

-- Delete jobs, proxies and credentials
IF EXISTS (select * from msdb.dbo.sysjobs WHERE name = N'Backup HumanResources')
EXEC msdb.dbo.sp_delete_job @job_name=N'Backup HumanResources', @delete_unused_schedule=1
GO

IF EXISTS (select * from msdb.dbo.sysjobs WHERE name = N'Back Up Database - HumanResources')
EXEC msdb.dbo.sp_delete_job @job_name=N'Back Up Database - HumanResources', @delete_unused_schedule=1
GO

IF EXISTS (select * from msdb.dbo.sysjobs WHERE name = N'Back Up Database - InternetSales')
EXEC msdb.dbo.sp_delete_job @job_name=N'Back Up Database - InternetSales', @delete_unused_schedule=1
GO

IF EXISTS (select * from msdb.dbo.sysjobs WHERE name = N'Back Up Log - InternetSales')
EXEC msdb.dbo.sp_delete_job @job_name=N'Back Up Log - InternetSales', @delete_unused_schedule=1
GO

IF EXISTS (select * from msdb.dbo.sysjobs WHERE name = N'Back Up Database - AWDataWarehouse')
EXEC msdb.dbo.sp_delete_job @job_name=N'Back Up Database - AWDataWarehouse', @delete_unused_schedule=1
GO

USE [msdb]
GO
IF EXISTS (select * from msdb.dbo.sysproxies where name = 'FileAgent_Proxy')
EXEC msdb.dbo.sp_delete_proxy @proxy_name=N'FileAgent_Proxy'
GO

USE [master]
GO
IF EXISTS (select * from sys.credentials where name = 'FileAgent_Credential')
DROP CREDENTIAL [FileAgent_Credential]
GO


-- Delete Log Full Alert
IF EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'InternetSales Log Full Alert')
	EXEC msdb.dbo.sp_delete_alert @name=N'InternetSales Log Full Alert'
GO

EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator=N'', 
		@notificationmethod=0
GO


-- Delete operators
IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'Student')
	EXEC msdb.dbo.sp_delete_operator @name=N'Student'
GO

IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'DBA Team')
	EXEC msdb.dbo.sp_delete_operator @name=N'DBA Team'
GO

-- Delete Database Mail account and profile
EXEC msdb.dbo.sp_set_sqlagent_properties @email_profile=N'', 
		@email_save_in_sent_folder=1, 
		@databasemail_profile=N''
GO

IF EXISTS (select * from msdb.dbo.sysmail_account WHERE name = 'AdventureWorks Administrator')
	EXECUTE msdb.dbo.sysmail_delete_account_sp    @account_name = 'AdventureWorks Administrator' ;
GO

IF EXISTS (select * from msdb.dbo.sysmail_profile WHERE name = 'SQL Server Agent Profile')
	EXECUTE msdb.dbo.sysmail_delete_profile_sp    @profile_name = 'SQL Server Agent Profile' ;
GO

-- Create Backup jobs
USE [msdb]
GO
DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'Back Up Database - InternetSales', 
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
EXEC msdb.dbo.sp_add_jobserver @job_name=N'Back Up Database - InternetSales', @server_name = N'MIA-SQL'
GO

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Back Up Database - InternetSales', @step_name=N'1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'BACKUP DATABASE [InternetSales] TO  DISK = N''D:\Labfiles\Lab10\Backups\InternetSales.bak'' WITH FORMAT, INIT,  MEDIANAME = N''InternetSales Backups'',  NAME = N''InternetSales-Full Database Backup'', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO
', 
		@database_name=N'master', 
		@flags=0
GO

EXEC msdb.dbo.sp_update_job @job_name=N'Back Up Database - InternetSales', 
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

DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'Back Up Log - InternetSales', 
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
EXEC msdb.dbo.sp_add_jobserver @job_name=N'Back Up Log - InternetSales', @server_name = N'MIA-SQL'
GO

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Back Up Log - InternetSales', @step_name=N'1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'BACKUP LOG [InternetSales] TO  DISK = N''D:\Labfiles\Lab10\Backups\InternetSales.bak'' WITH NOFORMAT, NOINIT,  NAME = N''InternetSales-Full Database Backup'', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO
', 
		@database_name=N'master', 
		@flags=0
GO

EXEC msdb.dbo.sp_update_job @job_name=N'Back Up Log - InternetSales', 
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


DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'Back Up Database - HumanResources', 
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
EXEC msdb.dbo.sp_add_jobserver @job_name=N'Back Up Database - HumanResources', @server_name = N'MIA-SQL'
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'Back Up Database - HumanResources', @step_name=N'1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'BACKUP DATABASE [HumanResources] TO  DISK = N''D:\Labfiles\Lab10\Backups\HumanResources.bak'' WITH NOFORMAT, NOINIT,  NAME = N''HumanResources-Full Database Backup'', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO
', 
		@database_name=N'master', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name=N'Back Up Database - HumanResources', 
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

DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'Back Up Database - AWDataWarehouse', 
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
EXEC msdb.dbo.sp_add_jobserver @job_name=N'Back Up Database - AWDataWarehouse', @server_name = N'MIA-SQL'
GO

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Back Up Database - AWDataWarehouse', @step_name=N'1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'BACKUP DATABASE [AWDataWarehouse] TO  DISK = N''A:\Labfiles\Lab10\Backups\AWDataWarehouse.bak'' WITH NOFORMAT, NOINIT,  NAME = N''AWDataWarehouse-Full Database Backup'', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO
', 
		@database_name=N'master', 
		@flags=0
GO

EXEC msdb.dbo.sp_update_job @job_name=N'Back Up Database - AWDataWarehouse', 
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

DELETE msdb.dbo.sysmail_event_log;
GO
DELETE msdb.dbo.sysmail_mailitems;
GO