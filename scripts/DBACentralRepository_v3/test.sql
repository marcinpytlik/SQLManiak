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
USE [DBACentralRepository];
GO
SELECT
    OBJECT_ID(N'perf.TableUsageTarget')      AS TableUsageTargetId,
    OBJECT_ID(N'perf.TableUsageSnapshot')    AS TableUsageSnapshotId,
    OBJECT_ID(N'perf.TableAccessAggregate')  AS TableAccessAggregateId,
    OBJECT_ID(N'perf.usp_ConfigureTableUsageTarget') AS ConfigureProcId;
SELECT *
FROM perf.TableUsageTarget;

USE [DBACentralRepository];
GO

DECLARE @TargetId bigint;

EXEC perf.usp_ConfigureTableUsageTarget
    @ServerInstance = N'localhost',
    @DatabaseName = N'AdventureWorks2022',
    @AuditPath = N'C:\SQLAudit\DBACentralRepository\',
    @TableUsageTargetId = @TargetId OUTPUT;

SELECT @TargetId AS TableUsageTargetId;
GO

SELECT *
FROM perf.TableUsageTarget;
GO

SELECT
    name,
    is_state_enabled,
    type_desc
FROM sys.server_audits
WHERE name = N'DBACR_TableAccess_AdventureWorks2022';
USE AdventureWorks2022;
GO

SELECT
    name,
    is_state_enabled
FROM sys.database_audit_specifications
WHERE name = N'DBACR_TableAccessSpec_AdventureWorks2022';
USE AdventureWorks2022;
GO

SELECT TOP (20) *
FROM Person.Person;

SELECT TOP (20) *
FROM Sales.SalesOrderHeader;

SELECT TOP (20) *
FROM Production.Product;
GO
USE DBACentralRepository;
GO

SELECT TOP (100) *
FROM perf.TableAccessAggregate
ORDER BY TableAccessAggregateId DESC;
GO

SELECT TOP (100) *
FROM perf.TableUsageSnapshot
ORDER BY TableUsageSnapshotId DESC;
GO
SELECT *
FROM report.vTableUsageDaily
WHERE DatabaseName = N'AdventureWorks2022'
ORDER BY CaptureDate DESC, SchemaName, ObjectName;
GO
.\Collect-DBACentralRepository.ps1 -ServerListPath '.\Servers.csv' -RepositoryServerInstance 'localhost' -RepositoryDatabase 'DBACentralRepository' -CollectionMode Full
.\Collect-DatabasePerformance.ps1  -RepositoryServerInstance 'localhost' -RepositoryDatabase 'DBACentralRepository'