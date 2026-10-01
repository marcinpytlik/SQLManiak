USE master;
GO

-- Disable buffer pool extension
ALTER SERVER CONFIGURATION
SET BUFFER POOL EXTENSION OFF;

--Reset tempdb to default location
ALTER DATABASE tempdb 
MODIFY FILE (NAME = tempdev, FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\tempdb.mdf');

ALTER DATABASE tempdb 
MODIFY FILE (NAME = templog, FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\templog.ldf');
GO



