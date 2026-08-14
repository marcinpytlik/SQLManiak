USE [DBACentralRepository];
GO

/* Walidacja instalacji — nie modyfikuje danych. */
SELECT
    [s].[name] AS [SchemaName],
    [o].[type_desc] AS [ObjectType],
    [o].[name] AS [ObjectName],
    [o].[create_date] AS [CreateDate],
    [o].[modify_date] AS [ModifyDate]
FROM [sys].[objects] AS [o]
INNER JOIN [sys].[schemas] AS [s]
    ON [s].[schema_id] = [o].[schema_id]
WHERE [s].[name] IN
(
    N'dbo', N'job', N'db', N'backup', N'capacity', N'ha', N'maintenance',
    N'patch', N'config', N'security', N'audit', N'alert', N'perf', N'report'
)
  AND [o].[is_ms_shipped] = 0
ORDER BY
    [s].[name],
    [o].[type_desc],
    [o].[name];
GO

SELECT
    [SchemaName] = [s].[name],
    [TableName] = [t].[name],
    [IndexName] = [i].[name],
    [i].[type_desc],
    [i].[is_unique],
    [i].[is_disabled]
FROM [sys].[indexes] AS [i]
INNER JOIN [sys].[tables] AS [t]
    ON [t].[object_id] = [i].[object_id]
INNER JOIN [sys].[schemas] AS [s]
    ON [s].[schema_id] = [t].[schema_id]
WHERE [i].[index_id] > 0
  AND [s].[name] IN
  (
      N'dbo', N'job', N'db', N'backup', N'capacity', N'ha', N'maintenance',
      N'patch', N'config', N'security', N'audit', N'alert', N'perf'
  )
ORDER BY
    [s].[name],
    [t].[name],
    [i].[index_id];
GO


SELECT
    [TableUsageTargetCount] = COUNT_BIG(*),
    [EnabledTableUsageTargetCount] = SUM(CONVERT(bigint,CASE WHEN IsEnabled=1 THEN 1 ELSE 0 END))
FROM [perf].[TableUsageTarget];
GO

SELECT
    [ObjectName],
    [ExistsFlag]
FROM
(
    VALUES
        (N'perf.TableUsageTarget', CASE WHEN OBJECT_ID(N'perf.TableUsageTarget',N'U') IS NOT NULL THEN 1 ELSE 0 END),
        (N'perf.TableUsageSnapshot', CASE WHEN OBJECT_ID(N'perf.TableUsageSnapshot',N'U') IS NOT NULL THEN 1 ELSE 0 END),
        (N'perf.TableAccessAggregate', CASE WHEN OBJECT_ID(N'perf.TableAccessAggregate',N'U') IS NOT NULL THEN 1 ELSE 0 END),
        (N'perf.usp_GetTableUsageByPrincipal', CASE WHEN OBJECT_ID(N'perf.usp_GetTableUsageByPrincipal',N'P') IS NOT NULL THEN 1 ELSE 0 END),
        (N'report.vTableUsageDaily', CASE WHEN OBJECT_ID(N'report.vTableUsageDaily',N'V') IS NOT NULL THEN 1 ELSE 0 END)
) AS X([ObjectName],[ExistsFlag]);
GO
