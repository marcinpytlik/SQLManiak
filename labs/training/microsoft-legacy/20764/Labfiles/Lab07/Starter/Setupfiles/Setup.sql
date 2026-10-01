USE master
GO

-- drop encryption keys
DROP CERTIFICATE EncryptedBackup;
GO
DROP MASTER KEY;
GO


IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'HumanResources')
BEGIN
	DROP DATABASE HumanResources
END
GO

RESTORE DATABASE HumanResources FROM  DISK = N'D:\SetupFiles\HumanResources_07.bak' WITH REPLACE;
GO
ALTER AUTHORIZATION ON DATABASE::HumanResources TO [AdventureWorks\Student];
GO

EXEC  msdb.dbo.sp_delete_database_backuphistory @database_name = 'HumanResources';
GO

IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'InternetSales')
BEGIN
	DROP DATABASE InternetSales
END
GO

RESTORE DATABASE InternetSales FROM  DISK = N'D:\SetupFiles\InternetSales_07.bak' WITH REPLACE;
GO
ALTER AUTHORIZATION ON DATABASE::InternetSales TO [AdventureWorks\Student];
GO

EXEC  msdb.dbo.sp_delete_database_backuphistory @database_name = 'InternetSales';
GO

IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'AWDataWarehouse')
BEGIN
	DROP DATABASE AWDataWarehouse
END
GO


EXEC  msdb.dbo.sp_delete_database_backuphistory @database_name = 'AWDataWarehouse';
GO


-- Set recovery model for HumanResources
ALTER DATABASE HumanResources SET RECOVERY SIMPLE WITH NO_WAIT;
GO

-- back up the database
BACKUP DATABASE HumanResources
TO  DISK = 'D:\Labfiles\Lab07\Backups\HumanResources.bak'
WITH FORMAT, INIT,  MEDIANAME = 'HumanResources Backup',  NAME = 'HumanResources-Full Database Backup', COMPRESSION;
GO

-- Modify the data
UPDATE HumanResources.dbo.Employee
SET PhoneNumber = '151-555-1234'
WHERE BusinessEntityID = 259;

-- Back up the database again
BACKUP DATABASE HumanResources
TO  DISK = 'D:\Labfiles\Lab07\Backups\HumanResources.bak'
WITH NOFORMAT, NOINIT,  NAME = 'HumanResources-Full Database Backup 2', COMPRESSION;
GO

-- Set the recovery model for InternetSales
ALTER DATABASE InternetSales SET RECOVERY FULL WITH NO_WAIT;
GO

-- Back up the database
BACKUP DATABASE InternetSales TO  DISK = 'D:\Labfiles\Lab07\Backups\InternetSales.bak'
WITH FORMAT, INIT,  MEDIANAME = 'Internet Sales Backup',  NAME = 'InternetSales-Full Database Backup', COMPRESSION;
GO

-- Modify the database
UPDATE InternetSales.dbo.Product
SET ListPrice = ListPrice * 1.1
WHERE ProductSubcategoryID = 1;

-- Back up the transaction log
BACKUP LOG InternetSales TO  DISK = 'D:\Labfiles\Lab07\Backups\InternetSales.bak'
WITH NOFORMAT, NOINIT,  NAME = 'InternetSales-Transaction Log Backup', COMPRESSION;
GO