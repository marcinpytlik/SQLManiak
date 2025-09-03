USE master;
GO

ALTER DATABASE tempdb 
MODIFY FILE (NAME = tempdev, SIZE = 10MB, FILEGROWTH = 5MB, FILENAME = 'T:\tempdb.mdf');

ALTER DATABASE tempdb 
MODIFY FILE (NAME = templog, SIZE=5MB, FILEGROWTH = 1MB, FILENAME = 'T:\templog.ldf');
GO
 

