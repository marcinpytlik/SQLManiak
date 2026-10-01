USE master
GO

-- Drop and restore Databases
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'salesapp1')
BEGIN
	DROP DATABASE salesapp1
END
GO



RESTORE DATABASE salesapp1 FROM  DISK = N'$(SUBDIR)SetupFiles\salesapp1.bak' WITH  REPLACE,
MOVE N'TSQL' TO N'$(SUBDIR)SetupFiles\salesapp1.mdf', 
MOVE N'TSQL_Log' TO N'$(SUBDIR)SetupFiles\salesapp1.ldf'
GO
ALTER AUTHORIZATION ON DATABASE::salesapp1 TO [ADVENTUREWORKS\Student];
GO


