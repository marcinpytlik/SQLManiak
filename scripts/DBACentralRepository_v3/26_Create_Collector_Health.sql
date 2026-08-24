USE [DBACentralRepository];
GO

/*=============================================================================
  DBACentralRepository
  Collector Health View

  Collectors:
    INVENTORY
    PERFORMANCE
    DATABASE_SCHEMA
    TABLE_USAGE
    BACKUP

  Time conventions:
    - INVENTORY, PERFORMANCE, DATABASE_SCHEMA and BACKUP use local server time.
    - TABLE_USAGE stores CapturedAt in UTC and is converted to
      Central European Standard Time before freshness calculation.
=============================================================================*/

CREATE OR ALTER VIEW [report].[vCollectorHealth]
AS
WITH [CollectorState] AS
(
    /*-------------------------------------------------------------------------
      INVENTORY
      Source: dbo.ScanRun
      Time convention: local server time
    -------------------------------------------------------------------------*/
    SELECT
        CONVERT(varchar(50), 'INVENTORY') AS [CollectorCode],

        MAX([sr].[ScanStartedAt]) AS [LastRunAt],

        MAX
        (
            CASE
                WHEN [sr].[Status] = 'SUCCESS'
                    THEN COALESCE([sr].[ScanFinishedAt], [sr].[ScanStartedAt])
            END
        ) AS [LastSuccessAt],

        (
            SELECT TOP (1)
                [sr2].[Status]
            FROM [dbo].[ScanRun] AS [sr2]
            WHERE [sr2].[ScanType] = 'Full'
            ORDER BY
                [sr2].[ScanStartedAt] DESC,
                [sr2].[ScanRunId] DESC
        ) AS [LastStatus],

        (
            SELECT TOP (1)
                [sr2].[CollectorHost]
            FROM [dbo].[ScanRun] AS [sr2]
            WHERE [sr2].[ScanType] = 'Full'
            ORDER BY
                [sr2].[ScanStartedAt] DESC,
                [sr2].[ScanRunId] DESC
        ) AS [CollectorHost],

        CONVERT
        (
            bigint,
            (
                SELECT TOP (1)
                    DATEDIFF_BIG
                    (
                        millisecond,
                        [sr2].[ScanStartedAt],
                        [sr2].[ScanFinishedAt]
                    )
                FROM [dbo].[ScanRun] AS [sr2]
                WHERE [sr2].[ScanType] = 'Full'
                ORDER BY
                    [sr2].[ScanStartedAt] DESC,
                    [sr2].[ScanRunId] DESC
            )
        ) AS [DurationMs],

        CONVERT(nvarchar(4000), NULL) AS [ErrorMessage]

    FROM [dbo].[ScanRun] AS [sr]
    WHERE [sr].[ScanType] = 'Full'


    UNION ALL


    /*-------------------------------------------------------------------------
      PERFORMANCE
      Source: perf.SampleBatch
      Time convention: local server time
    -------------------------------------------------------------------------*/
    SELECT
        CONVERT(varchar(50), 'PERFORMANCE') AS [CollectorCode],

        MAX([sb].[CapturedAt]) AS [LastRunAt],

        MAX
        (
            CASE
                WHEN [sb].[CollectionStatus] = 'SUCCESS'
                    THEN [sb].[CapturedAt]
            END
        ) AS [LastSuccessAt],

        (
            SELECT TOP (1)
                [sb2].[CollectionStatus]
            FROM [perf].[SampleBatch] AS [sb2]
            ORDER BY
                [sb2].[CapturedAt] DESC,
                [sb2].[SampleBatchId] DESC
        ) AS [LastStatus],

        (
            SELECT TOP (1)
                [sb2].[CollectorHost]
            FROM [perf].[SampleBatch] AS [sb2]
            ORDER BY
                [sb2].[CapturedAt] DESC,
                [sb2].[SampleBatchId] DESC
        ) AS [CollectorHost],

        CONVERT
        (
            bigint,
            (
                SELECT TOP (1)
                    [sb2].[DurationMs]
                FROM [perf].[SampleBatch] AS [sb2]
                ORDER BY
                    [sb2].[CapturedAt] DESC,
                    [sb2].[SampleBatchId] DESC
            )
        ) AS [DurationMs],

        CONVERT
        (
            nvarchar(4000),
            (
                SELECT TOP (1)
                    [sb2].[ErrorMessage]
                FROM [perf].[SampleBatch] AS [sb2]
                ORDER BY
                    [sb2].[CapturedAt] DESC,
                    [sb2].[SampleBatchId] DESC
            )
        ) AS [ErrorMessage]

    FROM [perf].[SampleBatch] AS [sb]


    UNION ALL


    /*-------------------------------------------------------------------------
      DATABASE_SCHEMA
      Source: db.DatabaseSchemaCollectionStatus
      Time convention: local server time
    -------------------------------------------------------------------------*/
    SELECT
        CONVERT(varchar(50), 'DATABASE_SCHEMA') AS [CollectorCode],

        MAX([ds].[StartedAt]) AS [LastRunAt],

        MAX
        (
            CASE
                WHEN [ds].[CollectionStatus] = 'SUCCESS'
                    THEN COALESCE([ds].[CompletedAt], [ds].[StartedAt])
            END
        ) AS [LastSuccessAt],

        (
            SELECT TOP (1)
                [ds2].[CollectionStatus]
            FROM [db].[DatabaseSchemaCollectionStatus] AS [ds2]
            ORDER BY
                [ds2].[StartedAt] DESC,
                [ds2].[DatabaseSchemaCollectionStatusId] DESC
        ) AS [LastStatus],

        CONVERT(nvarchar(256), NULL) AS [CollectorHost],

        CONVERT
        (
            bigint,
            (
                SELECT TOP (1)
                    DATEDIFF_BIG
                    (
                        millisecond,
                        [ds2].[StartedAt],
                        [ds2].[CompletedAt]
                    )
                FROM [db].[DatabaseSchemaCollectionStatus] AS [ds2]
                ORDER BY
                    [ds2].[StartedAt] DESC,
                    [ds2].[DatabaseSchemaCollectionStatusId] DESC
            )
        ) AS [DurationMs],

        CONVERT
        (
            nvarchar(4000),
            (
                SELECT TOP (1)
                    [ds2].[ErrorMessage]
                FROM [db].[DatabaseSchemaCollectionStatus] AS [ds2]
                ORDER BY
                    [ds2].[StartedAt] DESC,
                    [ds2].[DatabaseSchemaCollectionStatusId] DESC
            )
        ) AS [ErrorMessage]

    FROM [db].[DatabaseSchemaCollectionStatus] AS [ds]


    UNION ALL


    /*-------------------------------------------------------------------------
      TABLE_USAGE
      Source: perf.TableUsageSnapshot

      CapturedAt is stored as UTC by Collect-TableUsage.ps1.
      Normalize it to the local Windows time zone used by the other collector
      sources before freshness is calculated.
    -------------------------------------------------------------------------*/
    SELECT
        CONVERT(varchar(50), 'TABLE_USAGE') AS [CollectorCode],

        CONVERT
        (
            datetime2(0),
            MAX([tus].[CapturedAt])
                AT TIME ZONE 'UTC'
                AT TIME ZONE 'Central European Standard Time'
        ) AS [LastRunAt],

        CONVERT
        (
            datetime2(0),
            MAX([tus].[CapturedAt])
                AT TIME ZONE 'UTC'
                AT TIME ZONE 'Central European Standard Time'
        ) AS [LastSuccessAt],

        CASE
            WHEN MAX([tus].[CapturedAt]) IS NULL
                THEN NULL
            ELSE 'SUCCESS'
        END AS [LastStatus],

        CONVERT(nvarchar(256), NULL) AS [CollectorHost],

        CONVERT(bigint, NULL) AS [DurationMs],

        CONVERT(nvarchar(4000), NULL) AS [ErrorMessage]

    FROM [perf].[TableUsageSnapshot] AS [tus]


    UNION ALL


    /*-------------------------------------------------------------------------
      BACKUP
      Source: dbo.ScanRun
      ScanType: BACKUP
      Time convention: local server time
    -------------------------------------------------------------------------*/
    SELECT
        CONVERT(varchar(50), 'BACKUP') AS [CollectorCode],

        MAX([sr].[ScanStartedAt]) AS [LastRunAt],

        MAX
        (
            CASE
                WHEN [sr].[Status] = 'SUCCESS'
                    THEN COALESCE([sr].[ScanFinishedAt], [sr].[ScanStartedAt])
            END
        ) AS [LastSuccessAt],

        (
            SELECT TOP (1)
                [sr2].[Status]
            FROM [dbo].[ScanRun] AS [sr2]
            WHERE [sr2].[ScanType] = 'BACKUP'
            ORDER BY
                [sr2].[ScanStartedAt] DESC,
                [sr2].[ScanRunId] DESC
        ) AS [LastStatus],

        (
            SELECT TOP (1)
                [sr2].[CollectorHost]
            FROM [dbo].[ScanRun] AS [sr2]
            WHERE [sr2].[ScanType] = 'BACKUP'
            ORDER BY
                [sr2].[ScanStartedAt] DESC,
                [sr2].[ScanRunId] DESC
        ) AS [CollectorHost],

        CONVERT
        (
            bigint,
            (
                SELECT TOP (1)
                    DATEDIFF_BIG
                    (
                        millisecond,
                        [sr2].[ScanStartedAt],
                        [sr2].[ScanFinishedAt]
                    )
                FROM [dbo].[ScanRun] AS [sr2]
                WHERE [sr2].[ScanType] = 'BACKUP'
                ORDER BY
                    [sr2].[ScanStartedAt] DESC,
                    [sr2].[ScanRunId] DESC
            )
        ) AS [DurationMs],

        CONVERT(nvarchar(4000), NULL) AS [ErrorMessage]

    FROM [dbo].[ScanRun] AS [sr]
    WHERE [sr].[ScanType] = 'BACKUP'
),
[Health] AS
(
    SELECT
        [p].[CollectorCode],
        [p].[CollectorName],
        [s].[LastRunAt],
        [s].[LastSuccessAt],
        [s].[LastStatus],

        CASE
            WHEN [s].[LastSuccessAt] IS NULL
                THEN NULL
            ELSE DATEDIFF
            (
                minute,
                [s].[LastSuccessAt],
                SYSDATETIME()
            )
        END AS [MinutesSinceSuccess],

        [p].[ExpectedIntervalMinutes],
        [p].[WarningAfterMinutes],
        [p].[CriticalAfterMinutes],
        [s].[CollectorHost],
        [s].[DurationMs],
        [s].[ErrorMessage],
        [p].[IsEnabled]

    FROM [config].[CollectorPolicy] AS [p]

    LEFT JOIN [CollectorState] AS [s]
        ON [s].[CollectorCode] = [p].[CollectorCode]
)
SELECT
    [CollectorCode],
    [CollectorName],
    [LastRunAt],
    [LastSuccessAt],
    [LastStatus],
    [MinutesSinceSuccess],
    [ExpectedIntervalMinutes],
    [WarningAfterMinutes],
    [CriticalAfterMinutes],

    CASE
        WHEN [IsEnabled] = 0
            THEN 'DISABLED'

        WHEN [LastSuccessAt] IS NULL
            THEN 'NEVER_RUN'

        WHEN [MinutesSinceSuccess] >= [CriticalAfterMinutes]
            THEN 'CRITICAL'

        WHEN [MinutesSinceSuccess] >= [WarningAfterMinutes]
            THEN 'WARNING'

        ELSE 'OK'
    END AS [HealthStatus],

    [CollectorHost],
    [DurationMs],
    [ErrorMessage]

FROM [Health];
GO


/*=============================================================================
  Verification
=============================================================================*/

SELECT
    [CollectorCode],
    [CollectorName],
    [LastRunAt],
    [LastSuccessAt],
    [LastStatus],
    [MinutesSinceSuccess],
    [ExpectedIntervalMinutes],
    [WarningAfterMinutes],
    [CriticalAfterMinutes],
    [HealthStatus],
    [CollectorHost],
    [DurationMs],
    [ErrorMessage]
FROM [report].[vCollectorHealth]
ORDER BY [CollectorName];
GO