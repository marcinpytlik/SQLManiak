USE [master];
GO

CREATE LOGIN [grafana_reader]
WITH PASSWORD = 'TU_WSTAW_MOCNE_HASLO',
     CHECK_POLICY = ON,
     CHECK_EXPIRATION = OFF;
GO

USE [DBACentralRepository];
GO

CREATE USER [grafana_reader]
FOR LOGIN [grafana_reader];
GO
ALTER ROLE [db_datareader]
ADD MEMBER [grafana_reader];
GO
GRANT VIEW SERVER STATE TO [grafana_reader];
USE [AdventureWorks2022];
GO

SELECT TOP (5000)
    soh.[SalesOrderID],
    soh.[OrderDate],
    sod.[ProductID],
    sod.[OrderQty],
    sod.[LineTotal]
FROM [Sales].[SalesOrderHeader] AS soh
INNER JOIN [Sales].[SalesOrderDetail] AS sod
    ON sod.[SalesOrderID] = soh.[SalesOrderID]
ORDER BY
    soh.[OrderDate] DESC;
GO

SELECT
    p.[ProductID],
    p.[Name],
    COUNT_BIG(*) AS [OrderCount],
    SUM(sod.[OrderQty]) AS [Quantity]
FROM [Production].[Product] AS p
INNER JOIN [Sales].[SalesOrderDetail] AS sod
    ON sod.[ProductID] = p.[ProductID]
GROUP BY
    p.[ProductID],
    p.[Name]
ORDER BY
    [Quantity] DESC;
GO
USE [DBACentralRepository];
GO

GRANT EXECUTE
ON OBJECT::[perf].[usp_GetDatabaseLoadRanking]
TO [grafana_reader];
GO
.\Collect-DBACentralRepository.ps1 -ServerListPath '.\Servers.csv' -RepositoryServerInstance 'localhost' -RepositoryDatabase 'DBACentralRepository' -CollectionMode Full
.\Collect-DatabasePerformance.ps1  -RepositoryServerInstance 'localhost' -RepositoryDatabase 'DBACentralRepository'