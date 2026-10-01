USE master
GO

-- Drop and restore Databases
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'ExampleDB')
BEGIN
	DROP DATABASE ExampleDB
END
GO



RESTORE DATABASE [ExampleDB] FROM  DISK = N'$(SUBDIR)SetupFiles\TSQL.bak' WITH  REPLACE,
MOVE N'TSQL' TO N'$(SUBDIR)SetupFiles\ExampleDB.mdf', 
MOVE N'TSQL_Log' TO N'$(SUBDIR)SetupFiles\ExampleDB_log.ldf'
GO
ALTER AUTHORIZATION ON DATABASE::ExampleDB TO [ADVENTUREWORKS\Student];
GO

