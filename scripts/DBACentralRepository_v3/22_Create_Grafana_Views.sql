USE [DBACentralRepository];
GO

/*
===============================================================================
DBACentralRepository v3 - Grafana presentation layer
===============================================================================
Cel:
  Stabilna warstwa SQL dla dashboardów Grafana. Dashboardy nie powinny
  odwoływać się bezpośrednio do tabel snapshotowych, jeśli logika może być
  zamknięta w jednym widoku raportowym.

Ważne:
  Dane snapshotowe są zapisywane w lokalnym czasie SQL Servera.
  Grafana pracuje na filtrach czasu UTC, dlatego widoki czasowe konwertują
  CapturedAt z 'Central European Standard Time' do UTC.
===============================================================================
*/

CREATE OR ALTER VIEW [report].[vGrafanaInstances]
AS
SELECT
    I.[InstanceId],
    I.[ServerInstance],
    E.[EnvironmentCode],
    E.[EnvironmentName],
    I.[ProductVersion],
    I.[ProductLevel],
    I.[Edition],
    I.[ProductMajorVersion],
    I.[IsClustered],
    I.[IsHadrEnabled],
    I.[IsReachable],
    I.[LastSeenAt],
    I.[LastError]
FROM [dbo].[Instance] AS I
LEFT JOIN [dbo].[Environment] AS E
    ON E.[EnvironmentId] = I.[EnvironmentId]
WHERE I.[IsEnabled] = 1;
GO


CREATE OR ALTER VIEW [report].[vGrafanaDatabases]
AS
SELECT
    D.[InstanceId],
    D.[ServerInstance],
    D.[EnvironmentCode],
    D.[DatabaseId],
    D.[DatabaseName],
    D.[StateDesc],
    D.[RecoveryModelDesc],
    D.[CompatibilityLevel],
    D.[OwnerName],
    D.[IsQueryStoreOn],
    D.[IsEncrypted],
    D.[DataSizeMB],
    D.[LogSizeMB],
    D.[TotalSizeMB],
    D.[CapturedAt]
FROM [report].[vCurrentDatabases] AS D;
GO


CREATE OR ALTER VIEW [report].[vGrafanaJobs]
AS
WITH LastExecution AS
(
    SELECT
        E.[InstanceId],
        E.[JobId],
        E.[RunAt],
        E.[RunStatus],
        E.[RunStatusDescription],
        E.[DurationSeconds],
        E.[MessageText],
        ROW_NUMBER() OVER
        (
            PARTITION BY
                E.[InstanceId],
                E.[JobId]
            ORDER BY
                E.[RunAt] DESC,
                E.[JobExecutionId] DESC
        ) AS rn
    FROM [job].[JobExecution] AS E
)
SELECT
    J.[InstanceId],
    J.[ServerInstance],
    J.[EnvironmentCode],
    J.[JobId],
    J.[JobName],
    J.[CategoryName],
    J.[OwnerName],
    J.[IsEnabled],
    J.[OperatorName],
    J.[CapturedAt],
    X.[RunAt] AS [LastRunAt],
    X.[RunStatus] AS [LastRunStatus],
    X.[RunStatusDescription] AS [LastRunStatusDescription],
    X.[DurationSeconds] AS [LastDurationSeconds],
    X.[MessageText] AS [LastMessageText]
FROM [report].[vCurrentJobs] AS J
LEFT JOIN LastExecution AS X
    ON X.[InstanceId] = J.[InstanceId]
   AND X.[JobId] = J.[JobId]
   AND X.[rn] = 1;
GO


CREATE OR ALTER VIEW [report].[vGrafanaBackupStatus]
AS
WITH B AS
(
    SELECT
        H.[InstanceId],
        H.[DatabaseName],

        MAX
        (
            CASE
                WHEN H.[BackupType] = 'D'
                 AND H.[IsCopyOnly] = 0
                    THEN H.[BackupFinishDate]
            END
        ) AS [LastFull],

        MAX
        (
            CASE
                WHEN H.[BackupType] = 'I'
                    THEN H.[BackupFinishDate]
            END
        ) AS [LastDiff],

        MAX
        (
            CASE
                WHEN H.[BackupType] = 'L'
                    THEN H.[BackupFinishDate]
            END
        ) AS [LastLog]

    FROM [backup].[BackupHistory] AS H
    GROUP BY
        H.[InstanceId],
        H.[DatabaseName]
)
SELECT
    D.[InstanceId],
    D.[ServerInstance],
    D.[EnvironmentCode],
    D.[DatabaseName],
    D.[RecoveryModelDesc],
    B.[LastFull],
    B.[LastDiff],
    B.[LastLog],

    DATEDIFF
    (
        hour,
        B.[LastFull],
        SYSDATETIME()
    ) AS [FullAgeHours],

    DATEDIFF
    (
        minute,
        B.[LastLog],
        SYSDATETIME()
    ) AS [LogAgeMinutes],

    CASE
        WHEN B.[LastFull] IS NULL
            THEN 'NO_FULL'

        WHEN D.[RecoveryModelDesc] = 'FULL'
         AND B.[LastLog] IS NULL
            THEN 'NO_LOG'

        WHEN D.[RecoveryModelDesc] = 'FULL'
         AND DATEDIFF
             (
                 minute,
                 B.[LastLog],
                 SYSDATETIME()
             ) > 60
            THEN 'OLD_LOG'

        WHEN DATEDIFF
             (
                 hour,
                 B.[LastFull],
                 SYSDATETIME()
             ) > 36
            THEN 'OLD_FULL'

        ELSE 'OK'
    END AS [BackupStatus]

FROM [report].[vCurrentDatabases] AS D
LEFT JOIN B
    ON B.[InstanceId] = D.[InstanceId]
   AND B.[DatabaseName] = D.[DatabaseName]

WHERE D.[DatabaseName] <> N'tempdb';
GO


CREATE OR ALTER VIEW [report].[vGrafanaPatchStatus]
AS
WITH A AS
(
    SELECT
        P.*,

        ROW_NUMBER() OVER
        (
            PARTITION BY P.[InstanceId]
            ORDER BY
                P.[AssessedAt] DESC,
                P.[PatchAssessmentId] DESC
        ) AS rn

    FROM [patch].[PatchAssessment] AS P
)
SELECT
    I.[InstanceId],
    I.[ServerInstance],
    E.[EnvironmentCode],
    I.[ProductVersion] AS [InventoryVersion],
    A.[AssessedAt],
    A.[CurrentVersion],
    A.[RecommendedVersion],
    A.[AssessmentStatus],
    A.[MissingReleaseCount],
    A.[IsEndOfSupport],
    A.[Notes]

FROM [dbo].[Instance] AS I

LEFT JOIN [dbo].[Environment] AS E
    ON E.[EnvironmentId] = I.[EnvironmentId]

LEFT JOIN A
    ON A.[InstanceId] = I.[InstanceId]
   AND A.[rn] = 1

WHERE I.[IsEnabled] = 1;
GO


/*
===============================================================================
Performance Time Series

SampleBatch.CapturedAt jest zapisany w czasie lokalnym SQL Servera.
Grafana przekazuje $__timeFrom(), $__timeTo() oraz $__timeFilter() w UTC.

Dlatego:
    local CET/CEST -> UTC
===============================================================================
*/

CREATE OR ALTER VIEW [report].[vGrafanaPerformanceTimeSeries]
AS
SELECT

    CAST
    (
        B.[CapturedAt]
            AT TIME ZONE 'Central European Standard Time'
            AT TIME ZONE 'UTC'
        AS datetime2
    ) AS [Time],

    B.[InstanceId],
    I.[ServerInstance],
    E.[EnvironmentCode],

    D.[DatabaseName],

    D.[CpuMs],
    D.[ExecutionCount],
    D.[LogicalReads],
    D.[LogicalWrites],
    D.[PhysicalReads],

    M.[BufferPoolMB],
    M.[DirtyPagesMB],

    C.[ActiveRequests],
    C.[BlockedRequests],
    C.[CurrentWaitMs],

    L.[TransactionsCounter],
    L.[LogBytesFlushedCounter],
    L.[PercentLogUsed]

FROM [perf].[SampleBatch] AS B

INNER JOIN [dbo].[Instance] AS I
    ON I.[InstanceId] = B.[InstanceId]

LEFT JOIN [dbo].[Environment] AS E
    ON E.[EnvironmentId] = I.[EnvironmentId]

INNER JOIN [perf].[DatabaseCpuSnapshot] AS D
    ON D.[SampleBatchId] = B.[SampleBatchId]

LEFT JOIN [perf].[DatabaseMemorySnapshot] AS M
    ON M.[SampleBatchId] = B.[SampleBatchId]
   AND M.[DatabaseName] = D.[DatabaseName]

LEFT JOIN [perf].[DatabaseConcurrencySnapshot] AS C
    ON C.[SampleBatchId] = B.[SampleBatchId]
   AND C.[DatabaseName] = D.[DatabaseName]

LEFT JOIN [perf].[DatabaseLogSnapshot] AS L
    ON L.[SampleBatchId] = B.[SampleBatchId]
   AND L.[DatabaseName] = D.[DatabaseName]

WHERE B.[CollectionStatus] IN
(
    'SUCCESS',
    'PARTIAL'
);
GO


/*
===============================================================================
File I/O Time Series
===============================================================================
*/

CREATE OR ALTER VIEW [report].[vGrafanaFileIoTimeSeries]
AS
SELECT

    CAST
    (
        F.[CapturedAt]
            AT TIME ZONE 'Central European Standard Time'
            AT TIME ZONE 'UTC'
        AS datetime2
    ) AS [Time],

    F.[InstanceId],
    I.[ServerInstance],
    E.[EnvironmentCode],

    F.[DatabaseName],

    F.[FileId],
    F.[LogicalFileName],
    F.[FileType],

    F.[NumOfReads],
    F.[NumOfBytesRead],
    F.[IoStallReadMs],

    F.[NumOfWrites],
    F.[NumOfBytesWritten],
    F.[IoStallWriteMs]

FROM [perf].[FileIoSnapshot] AS F

INNER JOIN [dbo].[Instance] AS I
    ON I.[InstanceId] = F.[InstanceId]

LEFT JOIN [dbo].[Environment] AS E
    ON E.[EnvironmentId] = I.[EnvironmentId];
GO


/*
===============================================================================
Latest Performance State

Tu zachowujemy również oryginalny CapturedAt dla diagnostyki,
ale dodajemy CapturedAtUtc.
===============================================================================
*/

CREATE OR ALTER VIEW [report].[vGrafanaPerformanceLatest]
AS
SELECT
    P.[SampleBatchId],
    P.[InstanceId],
    P.[ServerInstance],
    E.[EnvironmentCode],

    P.[CapturedAt],

    CAST
    (
        P.[CapturedAt]
            AT TIME ZONE 'Central European Standard Time'
            AT TIME ZONE 'UTC'
        AS datetime2
    ) AS [CapturedAtUtc],

    P.[DatabaseName],

    P.[CpuMs],
    P.[ExecutionCount],
    P.[LogicalReads],

    P.[NumOfBytesRead],
    P.[NumOfBytesWritten],

    P.[BufferPoolMB],
    P.[DirtyPagesMB],

    P.[ActiveRequests],
    P.[BlockedRequests],
    P.[CurrentWaitMs]

FROM [perf].[vLatestDatabaseResourceSample] AS P

INNER JOIN [dbo].[Instance] AS I
    ON I.[InstanceId] = P.[InstanceId]

LEFT JOIN [dbo].[Environment] AS E
    ON E.[EnvironmentId] = I.[EnvironmentId];
GO


/*
===============================================================================
Verification
===============================================================================
*/

SELECT TOP (10)
    [Time],
    [ServerInstance],
    [DatabaseName],
    [CpuMs],
    [ExecutionCount],
    [LogicalReads],
    [BufferPoolMB],
    [ActiveRequests],
    [BlockedRequests]
FROM [report].[vGrafanaPerformanceTimeSeries]
ORDER BY [Time] DESC;
GO