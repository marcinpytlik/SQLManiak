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
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'AdventureWorks ')
BEGIN
	DROP DATABASE [AdventureWorks ]
END
GO

RESTORE DATABASE [AdventureWorks] FROM  DISK = N'D:\Setupfiles\AdventureWorks2016.bak' WITH  FILE = 1,  
MOVE N'AdventureWorks2016CTP3_Data' TO N'$(SUBDIR)SetupFiles\AdventureWorks_Data.mdf',  
MOVE N'AdventureWorks2016CTP3_Log' TO N'$(SUBDIR)SetupFiles\AdventureWorks_Log.ldf',  
MOVE N'AdventureWorks2016CTP3_mod' TO N'$(SUBDIR)SetupFiles\AdventureWorks_mod',  NOUNLOAD,  REPLACE,  STATS = 5

GO


ALTER AUTHORIZATION ON DATABASE::[AdventureWorks] TO [AdventureWorks\Student];
GO

EXEC  msdb.dbo.sp_delete_database_backuphistory @database_name = 'AdventureWorks';
GO

-- Drop HumanResources database
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'HumanResources')
BEGIN
	DROP DATABASE [HumanResources]
END
GO

-- Drop and restore MDW database
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'MDW')
BEGIN
	DROP DATABASE [MDW]
END
GO

USE AdventureWorks;
GO 

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'PromoteApp13')
	DROP LOGIN [PromoteApp13]
GO

CREATE LOGIN PromoteApp13 WITH PASSWORD = 'Pa$$w0rd', CHECK_EXPIRATION=OFF, CHECK_POLICY=ON;
GO

IF EXISTS (SELECT * FROM sys.database_principals WHERE name = N'PromoteApp13')
	DROP USER PromoteApp13;
GO
CREATE USER PromoteApp13 FOR LOGIN PromoteApp13;
GO

ALTER ROLE db_datareader ADD MEMBER PromoteApp13;
GO