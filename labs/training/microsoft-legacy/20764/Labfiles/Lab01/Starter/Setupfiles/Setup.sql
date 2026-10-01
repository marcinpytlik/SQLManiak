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

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'InternetSalesApplication')
	DROP LOGIN [InternetSalesApplication]
GO

CREATE LOGIN InternetSalesApplication WITH PASSWORD = 'Pa$$w0rd', CHECK_EXPIRATION=OFF, CHECK_POLICY=ON;
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



RESTORE DATABASE [AdventureWorks] FROM  DISK = N'D:\SetupFiles\AdventureWorks.bak' WITH  REPLACE,
MOVE N'AdventureWorks' TO N'$(SUBDIR)SetupFiles\AdventureWorks.mdf', 
MOVE N'AdventureWorks_Log' TO N'$(SUBDIR)SetupFiles\AdventureWorks_log.ldf'
GO
ALTER AUTHORIZATION ON DATABASE::AdventureWorks TO [AdventureWorks\Student];
GO

EXEC  msdb.dbo.sp_delete_database_backuphistory @database_name = 'AdventureWorks';
GO

CREATE DATABASE LegacySales;
GO
IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'LegacySalesLogin')
	DROP LOGIN [LegacySalesLogin]
GO
CREATE LOGIN LegacySalesLogin WITH PASSWORD = 'topsecret',  DEFAULT_DATABASE=[LegacySales], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF;
GO
DROP DATABASE LegacySales;
GO
ALTER LOGIN LegacySalesLogin DISABLE;
GO
