-- Update the Discontinued column for the Chai product
USE CorruptDB 
GO 

BEGIN TRANSACTION
	UPDATE dbo.Products
		SET Discontinued = '1' 
	WHERE EXISTS 
			(
				SELECT * 
				FROM dbo.Products 
				WHERE	ProductName = 'Chai'
				AND		Discontinued = 0
			)

/*
-- Commit the transaction 
-- Uncomment this section when someone's checked my query
COMMIT TRANSACTION
GO
*/

-- Simulate an automatic checkpoint
CHECKPOINT
GO

-- Try to access the CorruptDB database
SELECT * FROM CorruptDB.dbo.Products
/*
Msg 945, Level 14, State 2, Line 28
Database 'CorruptDB' cannot be opened due to inaccessible files or insufficient memory or disk space.  See the SQL Server errorlog for details.
*/


-- Check the status of the database
SELECT DATABASEPROPERTYEX (N'CorruptDB', N'STATUS'); 
GO

-- Confirm that the database is not online
SELECT * FROM sys.databases  WHERE state_desc <> 'ONLINE' 


-- Use Emergency mode to review the data in the database
ALTER DATABASE CorruptDB SET EMERGENCY

-- Review the state of the discontinued products data
USE CorruptDB
GO

SELECT COUNT(*) AS 'Product in Stock' 
FROM dbo.Products 
WHERE Discontinued = 0 


-- Set CorruptDB offline
USE master
GO

ALTER DATABASE CorruptDB SET OFFLINE
GO

-- After replacing the transaction log file, set CorruptDB back online
ALTER DATABASE CorruptDB SET ONLINE
GO

-- Set the database in single user mode and use DBCC CHECKDB to repair the database
ALTER DATABASE CorruptDB SET SINGLE_USER
GO

DBCC CHECKDB (N'CorruptDB', REPAIR_ALLOW_DATA_LOSS) WITH ALL_ERRORMSGS;
GO

-- Switch the database back into multi-user mode
ALTER DATABASE CorruptDB SET MULTI_USER 
GO

-- Check the data has returned to the pre-failure state 
USE CorruptDB
GO

SELECT COUNT(*) AS 'Product in Stock' 
FROM dbo.Products 
WHERE Discontinued = 0 

SELECT * FROM  CorruptDB.dbo.Products 
