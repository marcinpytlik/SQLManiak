USE master;
GO

ALTER DATABASE tempdb 
MODIFY FILE (NAME = tempdev, FILENAME = 'D:\tempdb.mdf');
ALTER DATABASE tempdb 
MODIFY FILE (NAME = temp2, FILENAME = 'D:\tempdb2.mdf');
ALTER DATABASE tempdb 
MODIFY FILE (NAME = temp3, FILENAME = 'D:\tempdb3.mdf');
ALTER DATABASE tempdb 
MODIFY FILE (NAME = temp4, FILENAME = 'D:\tempdb4.mdf');
ALTER DATABASE tempdb 
MODIFY FILE (NAME = temp5, FILENAME = 'D:\tempdb5.mdf');
ALTER DATABASE tempdb 
MODIFY FILE (NAME = temp6, FILENAME = 'D:\tempdb6.mdf');


ALTER DATABASE tempdb 
MODIFY FILE (NAME = templog, FILENAME = 'D:\templog.ldf');
GO
 

