-- Start partial restore of primary and Current filegroups
USE master;
RESTORE DATABASE AWDataWarehouse FILEGROUP='Current'
FROM DISK = 'D:\Labfiles\Lab07\Backups\AWDataWarehouse_Read-Write.bak'
WITH PARTIAL, FILE = 1, NORECOVERY;

-- restore latest differential backup and recover
RESTORE DATABASE AWDataWarehouse
FROM DISK = 'D:\Labfiles\Lab07\Backups\AWDataWarehouse_Read-Write.bak'
WITH FILE = 2, RECOVERY;

-- read-write data in Current filegroup is now online
SELECT TOP 1000 [ProductKey]
      ,[OrderDateKey]
      ,[CustomerKey]
      ,[SalesAmount]
      ,[TotalProductCost]
  FROM [AWDataWarehouse].[dbo].[FactInternetSales];

-- read-only data in Archive filegroup is still offline
SELECT TOP 1000 [ProductKey]
      ,[OrderDateKey]
      ,[CustomerKey]
      ,[SalesAmount]
      ,[TotalProductCost]
  FROM [AWDataWarehouse].[dbo].[FactInternetSalesArchive];

-- restore read-only Archive filegroup
RESTORE DATABASE AWDataWarehouse FILEGROUP='Archive'
FROM DISK = 'D:\Labfiles\Lab07\Backups\AWDataWarehouse_Read-Only.bak'
WITH RECOVERY;

-- All data is now online
SELECT TOP 1000 [ProductKey]
      ,[OrderDateKey]
      ,[CustomerKey]
      ,[SalesAmount]
      ,[TotalProductCost]
  FROM [AWDataWarehouse].[dbo].[FactInternetSalesArchive];