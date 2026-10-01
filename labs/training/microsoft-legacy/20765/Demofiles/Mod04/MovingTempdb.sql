USE master;
GO

ALTER DATABASE tempdb 
MODIFY FILE (NAME = tempdev, FILENAME = 'T:\tempdb.mdf');

ALTER DATABASE tempdb 
MODIFY FILE (NAME = templog, FILENAME = 'T:\templog.ldf');
GO
 

