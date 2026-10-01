-- View the statistics for index fragmentation on the Sales tables in the AdventureWorks database
USE Adventureworks 
GO

SELECT 
	DB_NAME(database_id) AS [Database]
,	OBJECT_SCHEMA_NAME(object_id) AS [Schema Name]
,	OBJECT_NAME(object_id) AS [Table]
,	index_id
,	avg_fragmentation_in_percent AS 'Fragmentation Percent'
FROM sys.dm_db_index_physical_stats(DEFAULT,DEFAULT,DEFAULT,DEFAULT,'LIMITED')
	WHERE DB_NAME(database_id) = 'Adventureworks' AND OBJECT_SCHEMA_NAME(object_id) = 'Sales'	
ORDER BY  avg_fragmentation_in_percent DESC, index_id ASC



-- View the statistics for index fragmentation on the SalesOrderHeader table
SELECT 
	DB_NAME(database_id) AS [Database]
,	OBJECT_SCHEMA_NAME(object_id) AS [Schema Name]
,	OBJECT_NAME(object_id) AS [Table]
,	index_id
,	avg_fragmentation_in_percent AS 'Fragmentation Percent'
FROM sys.dm_db_index_physical_stats(DEFAULT,DEFAULT,DEFAULT,DEFAULT,'LIMITED')
	WHERE DB_NAME(database_id) = 'Adventureworks' AND OBJECT_SCHEMA_NAME(object_id) = 'Sales' AND OBJECT_NAME(object_id) ='SalesOrderHeader' 
ORDER BY  index_id ASC



-- Insert an additional 10000 rows
SET NOCOUNT ON;
DECLARE @Counter int = 0;
WHILE @Counter < 10000 BEGIN
  INSERT INTO [Sales].[SalesOrderHeader] 
           ([RevisionNumber],[OrderDate],[DueDate],[Status],[OnlineOrderFlag],[CustomerID],[BillToAddressID],[ShipToAddressID],[ShipMethodID],[SubTotal],[TaxAmt],[Freight],[rowguid],[ModifiedDate])
     VALUES
           (3, GETDATE(), GETDATE(), 5, 0, 29825, 985, 985, 5, 100, 10, 10, NEWID(), GETDATE());
SET @Counter += 1;
END;
GO

-- View the statistics for index fragmentation following the data insertion
SELECT 
	DB_NAME(database_id) AS [Database]
,	OBJECT_SCHEMA_NAME(object_id) AS [Schema Name]
,	OBJECT_NAME(object_id) AS [Table]
,	index_id
,	avg_fragmentation_in_percent AS 'Fragmentation Percent'
FROM sys.dm_db_index_physical_stats(DEFAULT,DEFAULT,DEFAULT,DEFAULT,'LIMITED')
	WHERE DB_NAME(database_id) = 'Adventureworks' AND OBJECT_SCHEMA_NAME(object_id) = 'Sales' AND OBJECT_NAME(object_id) ='SalesOrderHeader' 
ORDER BY  index_id ASC


-- Rebuild the indexes
ALTER INDEX ALL ON Sales.SalesOrderHeader REBUILD;
GO


-- View the statistics for index fragmentation following the index rebuild
SELECT 
	DB_NAME(database_id) AS [Database]
,	OBJECT_SCHEMA_NAME(object_id) AS [Schema Name]
,	OBJECT_NAME(object_id) AS [Table]
,	index_id
,	avg_fragmentation_in_percent AS 'Fragmentation Percent'
FROM sys.dm_db_index_physical_stats(DEFAULT,DEFAULT,DEFAULT,DEFAULT,'LIMITED')
	WHERE DB_NAME(database_id) = 'Adventureworks' AND OBJECT_SCHEMA_NAME(object_id) = 'Sales' AND OBJECT_NAME(object_id) ='SalesOrderHeader' 
ORDER BY  index_id ASC


