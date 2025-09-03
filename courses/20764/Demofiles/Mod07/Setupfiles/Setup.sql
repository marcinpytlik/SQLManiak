USE master
GO

-- Drop and restore Databases
DROP DATABASE IF EXISTS TSQL;
DROP DATABASE IF EXISTS AdventureWorks;
DROP DATABASE IF EXISTS AdventureWorks2016CTP3;
GO

RESTORE DATABASE [TSQL] FROM  DISK = N'D:\SetupFiles\TSQL1.bak' WITH  REPLACE,
MOVE N'TSQL' TO N'$(SUBDIR)SetupFiles\TSQL.mdf', 
MOVE N'TSQL_Log' TO N'$(SUBDIR)SetupFiles\TSQL_log.ldf'
GO


RESTORE DATABASE [AdventureWorks] FROM  DISK = N'D:\SetupFiles\AdventureWorks2016.bak' WITH  REPLACE,
MOVE N'AdventureWorks2016CTP3_Data' TO N'$(SUBDIR)SetupFiles\AdventureWorks_Data.mdf', 
MOVE N'AdventureWorks2016CTP3_Log' TO N'$(SUBDIR)SetupFiles\AdventureWorks_log.ldf',
MOVE N'AdventureWorks2016CTP3_mod' TO N'$(SUBDIR)SetupFiles\AdventureWorks_mod.ldf'
GO

ALTER DATABASE adventureworks SET RECOVERY FULL
GO

BACKUP DATABASE AdventureWorks
TO DISK='D:\Demofiles\Mod07\Setupfiles\AdventureWorks.bak'
GO