USE master;
GO

-- Disable buffer pool extension
ALTER SERVER CONFIGURATION
SET BUFFER POOL EXTENSION OFF;

--Reset tempdb to default location
ALTER DATABASE tempdb 
MODIFY FILE (NAME = tempdev, SIZE = 8MB, FILEGROWTH = 10%, FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\tempdb.mdf');

ALTER DATABASE tempdb 
MODIFY FILE (NAME = templog, SIZE = 1MB, FILEGROWTH = 10%, FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\templog.ldf');
GO



