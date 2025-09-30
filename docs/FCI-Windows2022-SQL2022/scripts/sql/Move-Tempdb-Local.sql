USE master;
GO
ALTER DATABASE tempdb MODIFY FILE (NAME = tempdev,  FILENAME = 'T:\MSSQL\tempdb.mdf');
ALTER DATABASE tempdb MODIFY FILE (NAME = templog,  FILENAME = 'T:\MSSQL\templog.ldf');
-- Dodaj kolejne pliki w razie potrzeby:
-- ALTER DATABASE tempdb ADD FILE (NAME = temp2, FILENAME = 'T:\MSSQL\tempdb2.ndf', SIZE = 256MB, FILEGROWTH = 64MB);
GO
