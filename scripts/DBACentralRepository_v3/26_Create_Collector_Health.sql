USE [DBACentralRepository];
GO

/*=============================================================================
  DBACentralRepository - Collector Health
  Version: 1.0

  Purpose:
    - central policy for collector freshness/SLA,
    - unified health view over existing collector execution metadata,
    - no duplicate collector-run history is introduced.

  Time conventions currently used by the repository:
    dbo.ScanRun.ScanStartedAt / ScanFinishedAt              -> local server time
    perf.SampleBatch.CapturedAt                             -> local server time
    db.DatabaseSchemaCollectionStatus.StartedAt/CompletedAt -> local server time
    perf.TableUsageSnapshot.CapturedAt                      -> UTC

  report.vCollectorHealth normalizes TABLE_USAGE from UTC to local Windows
  time zone 'Central European Standard Time' before freshness is calculated.
=============================================================================*/

/*=============================================================================
  01. Collector policy
=============================================================================*/
IF OBJECT_ID(N'[config].[CollectorPolicy]', N'U') IS NULL
BEGIN
    CREATE TABLE [config].[CollectorPolicy]
    (
        [CollectorCode]               varchar(50)    NOT NULL,
        [CollectorName]               nvarchar(200)  NOT NULL,
        [ExpectedIntervalMinutes]     int            NOT NULL,
        [WarningAfterMinutes]         int            NOT NULL,
        [CriticalAfterMinutes]        int            NOT NULL,
        [IsEnabled]                   bit            NOT NULL
            CONSTRAINT [DF_config_CollectorPolicy_IsEnabled] DEFAULT (1),
        [Description]                 nvarchar(1000) NULL,

        CONSTRAINT [PK_config_CollectorPolicy]
            PRIMARY KEY CLUSTERED ([CollectorCode]),

        CONSTRAINT [CK_config_CollectorPolicy_Intervals]
            CHECK
            (
                [ExpectedIntervalMinutes] > 0
                AND [WarningAfterMinutes] >= [ExpectedIntervalMinutes]
                AND [CriticalAfterMinutes] >= [WarningAfterMinutes]
            )
    );
END;
GO

/*=============================================================================
  02. Default policies
=============================================================================*/
MERGE [config].[CollectorPolicy] AS [T]
USING
(
    VALUES
        (
            'INVENTORY',
            N'DBA Central Repository Inventory',
            1440,
            1500,
            1800,
            CONVERT(bit,1),
            N'Collect-DBACentralRepository.ps1'
        ),
        (
            'PERFORMANCE',
            N'Database Performance',
            5,
            10,
            20,
            CONVERT(bit,1),
            N'Collect-DatabasePerformance.ps1'
        ),
        (
            'DATABASE_SCHEMA',
            N'Database Schema',
            1440,
            1500,
            1800,
            CONVERT(bit,1),
            N'Collect-DatabaseSchema.ps1'
        ),
        (
            'TABLE_USAGE',
            N'Table Usage',
            15,
            30,
            60,
            CONVERT(bit,1),
            N'Collect-TableUsage.ps1'
        )
) AS [S]
(
    [CollectorCode],
    [CollectorName],
    [ExpectedIntervalMinutes],
    [WarningAfterMinutes],
    [CriticalAfterMinutes],
    [IsEnabled],
    [Description]
)
ON [T].[CollectorCode] = [S].[CollectorCode]
WHEN MATCHED THEN
    UPDATE SET
        [T].[CollectorName]               = [S].[CollectorName],
        [T].[ExpectedIntervalMinutes]     = [S].[ExpectedIntervalMinutes],
        [T].[WarningAfterMinutes]         = [S].[WarningAfterMinutes],
        [T].[CriticalAfterMinutes]        = [S].[CriticalAfterMinutes],
        [T].[IsEnabled]                   = [S].[IsEnabled],
        [T].[Description]                 = [S].[Description]
WHEN NOT MATCHED THEN
    INSERT
    (
        [CollectorCode],
        [CollectorName],
        [ExpectedIntervalMinutes],
        [WarningAfterMinutes],
        [CriticalAfterMinutes],
        [IsEnabled],
        [Description]
    )
    VALUES
    (
        [S].[CollectorCode],
        [S].[CollectorName],
        [S].[ExpectedIntervalMinutes],
        [S].[WarningAfterMinutes],
        [S].[CriticalAfterMinutes],
        [S].[IsEnabled],
        [S].[Description]
    );
GO

/*=============================================================================
  03. Unified collector health view
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
        CONVERT(varchar(50),'INVENTORY') AS [CollectorCode],
        MAX([sr].[ScanStartedAt]) AS [LastRunAt],
        MAX
        (
            CASE
                WHEN [sr].[Status] = 'SUCCESS'
                    THEN COALESCE([sr].[ScanFinishedAt],[sr].[ScanStartedAt])
            END
        ) AS [LastSuccessAt],
        (
            SELECT TOP (1) [sr2].[Status]
            FROM [dbo].[ScanRun] AS [sr2]
            WHERE [sr2].[ScanType] = 'Full'
            ORDER BY [sr2].[ScanStartedAt] DESC, [sr2].[ScanRunId] DESC
        ) AS [LastStatus],
        (
            SELECT TOP (1) [sr2].[CollectorHost]
            FROM [dbo].[ScanRun] AS [sr2]
            WHERE [sr2].[ScanType] = 'Full'
            ORDER BY [sr2].[ScanStartedAt] DESC, [sr2].[ScanRunId] DESC
        ) AS [CollectorHost],
        CONVERT
        (
            bigint,
            (
                SELECT TOP (1)
                    DATEDIFF_BIG(millisecond,[sr2].[ScanStartedAt],[sr2].[ScanFinishedAt])
                FROM [dbo].[ScanRun] AS [sr2]
                WHERE [sr2].[ScanType] = 'Full'
                ORDER BY [sr2].[ScanStartedAt] DESC, [sr2].[ScanRunId] DESC
            )
        ) AS [DurationMs],
        CONVERT(nvarchar(4000),NULL) AS [ErrorMessage]
    FROM [dbo].[ScanRun] AS [sr]
    WHERE [sr].[ScanType] = 'Full'

    UNION ALL

    /*-------------------------------------------------------------------------
      PERFORMANCE
      Source: perf.SampleBatch
      Time convention: local server time
    -------------------------------------------------------------------------*/
    SELECT
        CONVERT(varchar(50),'PERFORMANCE'),
        MAX([sb].[CapturedAt]),
        MAX
        (
            CASE
                WHEN [sb].[CollectionStatus] = 'SUCCESS'
                    THEN [sb].[CapturedAt]
            END
        ),
        (
            SELECT TOP (1) [sb2].[CollectionStatus]
            FROM [perf].[SampleBatch] AS [sb2]
            ORDER BY [sb2].[CapturedAt] DESC, [sb2].[SampleBatchId] DESC
        ),
        (
            SELECT TOP (1) [sb2].[CollectorHost]
            FROM [perf].[SampleBatch] AS [sb2]
            ORDER BY [sb2].[CapturedAt] DESC, [sb2].[SampleBatchId] DESC
        ),
        CONVERT
        (
            bigint,
            (
                SELECT TOP (1) [sb2].[DurationMs]
                FROM [perf].[SampleBatch] AS [sb2]
                ORDER BY [sb2].[CapturedAt] DESC, [sb2].[SampleBatchId] DESC
            )
        ),
        CONVERT
        (
            nvarchar(4000),
            (
                SELECT TOP (1) [sb2].[ErrorMessage]
                FROM [perf].[SampleBatch] AS [sb2]
                ORDER BY [sb2].[CapturedAt] DESC, [sb2].[SampleBatchId] DESC
            )
        )
    FROM [perf].[SampleBatch] AS [sb]

    UNION ALL

    /*-------------------------------------------------------------------------
      DATABASE_SCHEMA
      Source: db.DatabaseSchemaCollectionStatus
      Time convention: local server time
    -------------------------------------------------------------------------*/
    SELECT
        CONVERT(varchar(50),'DATABASE_SCHEMA'),
        MAX([ds].[StartedAt]),
        MAX
        (
            CASE
                WHEN [ds].[CollectionStatus] = 'SUCCESS'
                    THEN COALESCE([ds].[CompletedAt],[ds].[StartedAt])
            END
        ),
        (
            SELECT TOP (1) [ds2].[CollectionStatus]
            FROM [db].[DatabaseSchemaCollectionStatus] AS [ds2]
            ORDER BY [ds2].[StartedAt] DESC, [ds2].[DatabaseSchemaCollectionStatusId] DESC
        ),
        CONVERT(nvarchar(256),NULL),
        CONVERT
        (
            bigint,
            (
                SELECT TOP (1)
                    DATEDIFF_BIG(millisecond,[ds2].[StartedAt],[ds2].[CompletedAt])
                FROM [db].[DatabaseSchemaCollectionStatus] AS [ds2]
                ORDER BY [ds2].[StartedAt] DESC, [ds2].[DatabaseSchemaCollectionStatusId] DESC
            )
        ),
        CONVERT
        (
            nvarchar(4000),
            (
                SELECT TOP (1) [ds2].[ErrorMessage]
                FROM [db].[DatabaseSchemaCollectionStatus] AS [ds2]
                ORDER BY [ds2].[StartedAt] DESC, [ds2].[DatabaseSchemaCollectionStatusId] DESC
            )
        )
    FROM [db].[DatabaseSchemaCollectionStatus] AS [ds]

    UNION ALL

    /*-------------------------------------------------------------------------
      TABLE_USAGE
      Source: perf.TableUsageSnapshot

      CapturedAt is stored as UTC by Collect-TableUsage.ps1.  Normalize it to
      the local Windows time zone used by the other collector sources before
      freshness is calculated.
    -------------------------------------------------------------------------*/
    SELECT
        CONVERT(varchar(50),'TABLE_USAGE'),
        CONVERT
        (
            datetime2(0),
            MAX([tus].[CapturedAt])
                AT TIME ZONE 'UTC'
                AT TIME ZONE 'Central European Standard Time'
        ),
        CONVERT
        (
            datetime2(0),
            MAX([tus].[CapturedAt])
                AT TIME ZONE 'UTC'
                AT TIME ZONE 'Central European Standard Time'
        ),
        CASE
            WHEN MAX([tus].[CapturedAt]) IS NULL THEN NULL
            ELSE 'SUCCESS'
        END,
        CONVERT(nvarchar(256),NULL),
        CONVERT(bigint,NULL),
        CONVERT(nvarchar(4000),NULL)
    FROM [perf].[TableUsageSnapshot] AS [tus]
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
            WHEN [s].[LastSuccessAt] IS NULL THEN NULL
            ELSE DATEDIFF(minute,[s].[LastSuccessAt],SYSDATETIME())
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
        WHEN [IsEnabled] = 0 THEN 'DISABLED'
        WHEN [LastSuccessAt] IS NULL THEN 'NEVER_RUN'
        WHEN [MinutesSinceSuccess] >= [CriticalAfterMinutes] THEN 'CRITICAL'
        WHEN [MinutesSinceSuccess] >= [WarningAfterMinutes] THEN 'WARNING'
        ELSE 'OK'
    END AS [HealthStatus],
    [CollectorHost],
    [DurationMs],
    [ErrorMessage]
FROM [Health];
GO

/*=============================================================================
  04. Verification
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
ORDER BY [CollectorCode];
GO
