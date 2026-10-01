USE master
GO

ALTER DATABASE AdventureWorks ADD FILEGROUP ReadOnlyFG;
GO

ALTER DATABASE AdventureWorks ADD FILE (
name = ReadOnlyFile,
FILENAME = 'D:\Labfiles\Lab06\Starter\Data\ReadOnlyFile.ndf')
TO FILEGROUP ReadOnlyFG
GO

USE AdventureWorks
GO

CREATE TABLE demoTable (id INT, Longname CHAR(8000))
ON ReadOnlyFG
GO

ALTER DATABASE AdventureWorks MODIFY FILEGROUP ReadOnlyFG READ_ONLY;
GO