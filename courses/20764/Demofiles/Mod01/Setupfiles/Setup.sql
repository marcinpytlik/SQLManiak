USE master
GO




IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'Payroll_Application')
	DROP LOGIN [Payroll_Application]
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'Web_Application')
	DROP LOGIN [Web_Application]
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'ADVENTUREWORKS\AnthonyFrizzell')
	DROP LOGIN [ADVENTUREWORKS\AnthonyFrizzell]
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'ADVENTUREWORKS\Database_Managers')
	DROP LOGIN [ADVENTUREWORKS\Database_Managers]
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'ADVENTUREWORKS\HumanResources_Users')
	DROP LOGIN [ADVENTUREWORKS\HumanResources_Users]
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'AW_securitymanager' AND type = 'R')
	DROP SERVER ROLE [AW_securitymanager]
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

-- Drop and restore TSQL database
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'TSQL')
BEGIN
	DROP DATABASE TSQL
END
GO

RESTORE DATABASE TSQL FROM  DISK = N'D:\SetupFiles\TSQL1.bak' WITH  REPLACE,
MOVE N'TSQL' TO N'$(SUBDIR)SetupFiles\TSQL.mdf', 
MOVE N'TSQL_Log' TO N'$(SUBDIR)SetupFiles\TSQL_log.ldf'
GO
ALTER AUTHORIZATION ON DATABASE::TSQL TO [AdventureWorks\Student];
GO

EXEC  msdb.dbo.sp_delete_database_backuphistory @database_name = 'TSQL';
GO

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'appuser')
	CREATE LOGIN appuser WITH PASSWORD = 'Pa$$w0rd'
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'reportuser')
	DROP LOGIN [reportuser];
GO