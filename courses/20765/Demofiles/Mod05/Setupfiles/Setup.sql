USE master
GO

IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'AdventureWorks')
BEGIN
	DROP DATABASE AdventureWorks
END
GO

IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'CorruptDB')
BEGIN
	DROP DATABASE CorruptDB
END
GO

RESTORE DATABASE [CorruptDB] FROM  DISK = N'$(SUBDIR)SetupFiles\CorruptDB.bak' WITH  REPLACE,
MOVE N'Northwind' TO N'$(SUBDIR)Data\CorruptDB_Data.mdf', 
MOVE N'NorthWind_Log' TO N'$(SUBDIR)Data\CorruptDB_log.ldf'
GO

RESTORE DATABASE [AdventureWorks] FROM  DISK = N'$(SUBDIR)SetupFiles\AdventureWorks.bak' WITH  REPLACE,
MOVE N'AdventureWorks2012_Data' TO N'$(SUBDIR)Data\AdventureWorks_Data.mdf', 
MOVE N'AdventureWorks2012_Log' TO N'$(SUBDIR)Data\AdventureWorks_log.ldf'
GO
