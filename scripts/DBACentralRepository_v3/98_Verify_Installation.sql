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
    N'patch', N'config', N'security', N'audit', N'alert', N'perf', N'report', N'perf'
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
