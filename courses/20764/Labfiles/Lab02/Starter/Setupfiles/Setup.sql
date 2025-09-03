USE master
GO

-- Drop and restore Databases
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'salesapp1')
BEGIN
	DROP DATABASE salesapp1
END
GO



RESTORE DATABASE salesapp1 FROM  DISK = N'D:\SetupFiles\salesapp1.bak' WITH  REPLACE,
MOVE N'TSQL' TO N'$(SUBDIR)SetupFiles\salesapp1.mdf', 
MOVE N'TSQL_Log' TO N'$(SUBDIR)SetupFiles\salesapp1.ldf'
GO
ALTER AUTHORIZATION ON DATABASE::salesapp1 TO [ADVENTUREWORKS\Student];
GO

IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'AdventureWorks')
BEGIN
	DROP DATABASE AdventureWorks
END
GO



IF EXISTS (SELECT * FROM sys.server_principals WHERE name ='ADVENTUREWORKS\Database_Managers')
	DROP LOGIN [ADVENTUREWORKS\Database_Managers]
GO
CREATE LOGIN [ADVENTUREWORKS\Database_Managers] FROM WINDOWS;
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name ='ADVENTUREWORKS\InternetSales_Users')
	DROP LOGIN [ADVENTUREWORKS\InternetSales_Users]
GO
CREATE LOGIN [ADVENTUREWORKS\InternetSales_Users] FROM WINDOWS;
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name ='ADVENTUREWORKS\InternetSales_Managers')
	DROP LOGIN [ADVENTUREWORKS\InternetSales_Managers]
GO
CREATE LOGIN [ADVENTUREWORKS\InternetSales_Managers] FROM WINDOWS;
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name ='Marketing_Application')
	DROP LOGIN Marketing_Application
GO
CREATE LOGIN Marketing_Application WITH PASSWORD = 'Pa$$w0rd';
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name ='ADVENTUREWORKS\WebApplicationSvc')
	DROP LOGIN [ADVENTUREWORKS\WebApplicationSvc]
GO
CREATE LOGIN [ADVENTUREWORKS\WebApplicationSvc] FROM WINDOWS;
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'database_manager' AND type = 'R')
	DROP SERVER ROLE database_manager;
GO

