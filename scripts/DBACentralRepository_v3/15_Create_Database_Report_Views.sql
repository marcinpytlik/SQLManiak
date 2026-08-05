USE [DBACentralRepository];
GO

/*
===============================================================================
15_Create_Database_Report_Views.sql

Brakujące widoki bieżącego stanu dla plików baz i największych tabel.
===============================================================================
*/

CREATE OR ALTER VIEW [report].[vCurrentDatabaseFiles]
AS
WITH CurrentRows AS
(
    SELECT
        F.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY
                F.[InstanceId],
                F.[DatabaseName],
                F.[FileId]
            ORDER BY
                F.[CapturedAt] DESC,
                F.[DatabaseFileSnapshotId] DESC
        ) AS [RowNumber]
    FROM [db].[DatabaseFileSnapshot] AS F
)
SELECT
    I.[ServerInstance],
    E.[EnvironmentCode],
    C.*
FROM CurrentRows AS C
INNER JOIN [dbo].[Instance] AS I
    ON I.[InstanceId] = C.[InstanceId]
LEFT JOIN [dbo].[Environment] AS E
    ON E.[EnvironmentId] = I.[EnvironmentId]
WHERE C.[RowNumber] = 1;
GO


CREATE OR ALTER VIEW [report].[vCurrentLargestTables]
AS
WITH CurrentRows AS
(
    SELECT
        T.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY
                T.[InstanceId],
                T.[DatabaseName],
                T.[SchemaName],
                T.[TableName]
            ORDER BY
                T.[CapturedAt] DESC,
                T.[LargestTableSnapshotId] DESC
        ) AS [RowNumber]
    FROM [db].[LargestTableSnapshot] AS T
)
SELECT
    I.[ServerInstance],
    E.[EnvironmentCode],
    C.*
FROM CurrentRows AS C
INNER JOIN [dbo].[Instance] AS I
    ON I.[InstanceId] = C.[InstanceId]
LEFT JOIN [dbo].[Environment] AS E
    ON E.[EnvironmentId] = I.[EnvironmentId]
WHERE C.[RowNumber] = 1;
GO
