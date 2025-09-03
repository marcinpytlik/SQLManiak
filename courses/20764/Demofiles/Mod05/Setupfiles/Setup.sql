USE master;
GO

IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'LogTest')
BEGIN
	DROP DATABASE LogTest;
END
GO

CREATE DATABASE LogTest
on
(
name = LogTestData1,
filename = N'$(SUBDIR)Setupfiles\LogTestData1.mdf'
)
log on
(
name = LogTestLog1,
filename = N'$(SUBDIR)Setupfiles\LogTestLog1.ldf'
);
go

USE LogTest;
GO

CREATE TABLE tLogTest
(
col1 int
);
GO





IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'AdventureWorks2016')
BEGIN
	DROP DATABASE AdventureWorks2016;
END
GO

RESTORE DATABASE [AdventureWorks2016] FROM  DISK = N'D:\Setupfiles\AdventureWorks2016.bak' WITH REPLACE,
MOVE N'AdventureWorks2016_Data' TO N'$(SUBDIR)Setupfiles\AdventureWorks_Data.mdf', 
MOVE N'AdventureWorks2016_Log' TO N'$(SUBDIR)Setupfiles\AdventureWorks_log.ldf',
MOVE N'AdventureWorks2016_mod' TO N'$(SUBDIR)Setupfiles\AdventureWorks_mod'
GO


ALTER AUTHORIZATION ON DATABASE::AdventureWorks2016 TO [ADVENTUREWORKS\Student];
GO
ALTER AUTHORIZATION ON DATABASE::LogTest TO [ADVENTUREWORKS\Student];
GO
