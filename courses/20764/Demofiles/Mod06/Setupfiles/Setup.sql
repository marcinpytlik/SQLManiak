USE master
GO

-- Drop and restore Databases


-- Drop the AdventureWorks Database if this Already Exists
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'AdventureWorks')
BEGIN
	DROP DATABASE AdventureWorks
END
GO

-- Restore the AdventureWorks Database
RESTORE DATABASE [AdventureWorks] FROM  DISK = N'D:\SetupFiles\AdventureWorks2016.bak' WITH  REPLACE,
MOVE N'AdventureWorks2016CTP3_Data' TO N'$(SUBDIR)SetupFiles\AdventureWorks_Data.mdf', 
MOVE N'AdventureWorks2016CTP3_Log' TO N'$(SUBDIR)SetupFiles\AdventureWorks_log.ldf',
MOVE N'AdventureWorks2016CTP3_mod' TO N'$(SUBDIR)SetupFiles\AdventureWorks_mod'
GO
ALTER AUTHORIZATION ON DATABASE::AdventureWorks TO [ADVENTUREWORKS\Student];
GO