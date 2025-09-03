---------------------------------------------------------------------
-- LAB 03
--
-- Exercise 2
---------------------------------------------------------------------

USE master;
GO

---------------------------------------------------------------------
-- Task 1 
-- 
-- Restore the backup D:\Labfiles\Lab03\Starter\TSQL1.bak to the MIA-SQL instance. 
-- Leave the database in the NORECOVERY state so that additional transaction logs can be restored.
---------------------------------------------------------------------
RESTORE DATABASE [TSQL] FROM
  DISK = N'D:\Labfiles\Lab03\Starter\TSQL1.bak' WITH  FILE = 1,  
  MOVE N'TSQL' TO N'D:\Labfiles\Lab03\TSQL.mdf',
  MOVE N'TSQL_log' TO N'D:\Labfiles\Lab03\TSQL_log.ldf',
  NORECOVERY,  NOUNLOAD,  STATS = 5
GO

---------------------------------------------------------------------
-- Task 2
-- 
-- Restore the transaction log backup D:\Labfiles\Lab03\Starter\TSQL1_trn1.trn to the 
-- TSQL database you have restored on the MIA-SQL instance. 
-- Leave the database in the RECOVERY state so that the database can be used.
---------------------------------------------------------------------
RESTORE LOG [TSQL] FROM
  DISK = N'D:\Labfiles\Lab03\Starter\TSQL1_trn1.trn' WITH  FILE = 1,
  NOUNLOAD,  STATS = 10
GO

---------------------------------------------------------------------
-- Task 3 
-- 
-- Update the database statistics for the TSQL database with the up_updatestats system stored procedure.
---------------------------------------------------------------------
EXEC TSQL.sys.sp_updatestats; 
