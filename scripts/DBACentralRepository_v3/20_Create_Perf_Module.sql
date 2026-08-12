USE [DBACentralRepository];
GO

/*
===============================================================================
DBACentralRepository v3 - PERF module v1.0
===============================================================================
Cel:
  Historyczny pomiar obciążenia baz danych na poziomie instancji SQL Server.

Założenia:
  - nie tworzy dbo.ScanRun dla każdego krótkiego sampla;
  - korzysta z istniejącego dbo.Instance;
  - przechowuje raw/cumulative counters;
  - delty i udziały procentowe są liczone w procedurach raportowych;
  - zgodność: SQL Server 2016 SP1+ / 2019 / 2022 / 2025.

Grupy:
  1. CPU / workload         -> perf.DatabaseCpuSnapshot
  2. I/O per file          -> perf.FileIoSnapshot
  3. Buffer Pool           -> perf.DatabaseMemorySnapshot
  4. Log / transactions    -> perf.DatabaseLogSnapshot
  5. Concurrency / waits   -> perf.DatabaseConcurrencySnapshot

WAŻNE:
  CpuMs jest atrybucją na podstawie aktualnego plan cache
  (sys.dm_exec_query_stats + dbid planu). Eviction/recompile/restart może
  spowodować spadek licznika; raporty traktują takie przypadki jako reset.
===============================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF SCHEMA_ID(N'perf') IS NULL
    EXEC(N'CREATE SCHEMA [perf] AUTHORIZATION [dbo];');
GO

/*=============================================================================
  01. Sample batch
=============================================================================*/
IF OBJECT_ID(N'[perf].[SampleBatch]', N'U') IS NULL
BEGIN
    CREATE TABLE [perf].[SampleBatch]
    (
        [SampleBatchId]      bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT [PK_perf_SampleBatch] PRIMARY KEY,
        [InstanceId]         bigint NOT NULL,
        [CapturedAt]         datetime2(0) NOT NULL,
        [CollectorHost]      nvarchar(128) NULL,
        [CollectorUser]      nvarchar(256) NULL,
        [CollectorVersion]   varchar(20) NOT NULL
            CONSTRAINT [DF_perf_SampleBatch_CollectorVersion] DEFAULT ('1.0'),
        [CollectionStatus]   varchar(20) NOT NULL
            CONSTRAINT [DF_perf_SampleBatch_Status] DEFAULT ('STARTED'),
        [DurationMs]         int NULL,
        [ErrorMessage]       nvarchar(4000) NULL,

        CONSTRAINT [FK_perf_SampleBatch_Instance]
            FOREIGN KEY ([InstanceId])
            REFERENCES [dbo].[Instance] ([InstanceId]),

        CONSTRAINT [CK_perf_SampleBatch_Status]
            CHECK ([CollectionStatus] IN ('STARTED','SUCCESS','FAILED','PARTIAL'))
    );

    CREATE INDEX [IX_perf_SampleBatch_Instance_CapturedAt]
        ON [perf].[SampleBatch] ([InstanceId], [CapturedAt] DESC)
        INCLUDE ([CollectionStatus], [DurationMs]);
END;
GO

/*=============================================================================
  02. CPU / workload snapshot
=============================================================================*/
IF OBJECT_ID(N'[perf].[DatabaseCpuSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [perf].[DatabaseCpuSnapshot]
    (
        [DatabaseCpuSnapshotId] bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT [PK_perf_DatabaseCpuSnapshot] PRIMARY KEY,
        [SampleBatchId]          bigint NOT NULL,
        [InstanceId]             bigint NOT NULL,
        [CapturedAt]             datetime2(0) NOT NULL,
        [DatabaseId]             int NOT NULL,
        [DatabaseName]           sysname NOT NULL,

        [CachedQueryCount]       bigint NOT NULL,
        [ExecutionCount]         bigint NOT NULL,
        [CpuMs]                  bigint NOT NULL,
        [ElapsedMs]              bigint NOT NULL,
        [LogicalReads]           bigint NOT NULL,
        [LogicalWrites]          bigint NOT NULL,
        [PhysicalReads]          bigint NOT NULL,

        CONSTRAINT [FK_perf_DatabaseCpuSnapshot_Batch]
            FOREIGN KEY ([SampleBatchId])
            REFERENCES [perf].[SampleBatch] ([SampleBatchId]),

        CONSTRAINT [FK_perf_DatabaseCpuSnapshot_Instance]
            FOREIGN KEY ([InstanceId])
            REFERENCES [dbo].[Instance] ([InstanceId])
    );

    CREATE UNIQUE INDEX [UX_perf_DatabaseCpuSnapshot_Batch_Db]
        ON [perf].[DatabaseCpuSnapshot] ([SampleBatchId], [DatabaseId]);

    CREATE INDEX [IX_perf_DatabaseCpuSnapshot_History]
        ON [perf].[DatabaseCpuSnapshot]
        (
            [InstanceId],
            [DatabaseName],
            [CapturedAt] DESC
        )
        INCLUDE
        (
            [CpuMs],
            [ExecutionCount],
            [LogicalReads],
            [LogicalWrites],
            [PhysicalReads]
        );
END;
GO

/*=============================================================================
  03. File I/O snapshot
=============================================================================*/
IF OBJECT_ID(N'[perf].[FileIoSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [perf].[FileIoSnapshot]
    (
        [FileIoSnapshotId]   bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT [PK_perf_FileIoSnapshot] PRIMARY KEY,
        [SampleBatchId]      bigint NOT NULL,
        [InstanceId]         bigint NOT NULL,
        [CapturedAt]         datetime2(0) NOT NULL,
        [DatabaseId]         int NOT NULL,
        [DatabaseName]       sysname NOT NULL,
        [FileId]             int NOT NULL,
        [LogicalFileName]    sysname NULL,
        [FileType]           varchar(10) NULL,

        [NumOfReads]         bigint NOT NULL,
        [NumOfBytesRead]     bigint NOT NULL,
        [IoStallReadMs]      bigint NOT NULL,
        [NumOfWrites]        bigint NOT NULL,
        [NumOfBytesWritten]  bigint NOT NULL,
        [IoStallWriteMs]     bigint NOT NULL,
        [IoStallMs]          bigint NOT NULL,
        [SizeOnDiskBytes]    bigint NULL,
        [SampleMs]           bigint NULL,

        CONSTRAINT [FK_perf_FileIoSnapshot_Batch]
            FOREIGN KEY ([SampleBatchId])
            REFERENCES [perf].[SampleBatch] ([SampleBatchId]),

        CONSTRAINT [FK_perf_FileIoSnapshot_Instance]
            FOREIGN KEY ([InstanceId])
            REFERENCES [dbo].[Instance] ([InstanceId])
    );

    CREATE UNIQUE INDEX [UX_perf_FileIoSnapshot_Batch_File]
        ON [perf].[FileIoSnapshot]
        (
            [SampleBatchId],
            [DatabaseId],
            [FileId]
        );

    CREATE INDEX [IX_perf_FileIoSnapshot_History]
        ON [perf].[FileIoSnapshot]
        (
            [InstanceId],
            [DatabaseName],
            [CapturedAt] DESC
        )
        INCLUDE
        (
            [FileType],
            [NumOfReads],
            [NumOfBytesRead],
            [IoStallReadMs],
            [NumOfWrites],
            [NumOfBytesWritten],
            [IoStallWriteMs]
        );
END;
GO

/*=============================================================================
  04. Buffer Pool snapshot
=============================================================================*/
IF OBJECT_ID(N'[perf].[DatabaseMemorySnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [perf].[DatabaseMemorySnapshot]
    (
        [DatabaseMemorySnapshotId] bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT [PK_perf_DatabaseMemorySnapshot] PRIMARY KEY,
        [SampleBatchId]             bigint NOT NULL,
        [InstanceId]                bigint NOT NULL,
        [CapturedAt]                datetime2(0) NOT NULL,
        [DatabaseId]                int NOT NULL,
        [DatabaseName]              sysname NOT NULL,

        [BufferPoolPages]           bigint NOT NULL,
        [BufferPoolMB]              decimal(19,2) NOT NULL,
        [DirtyPages]                bigint NOT NULL,
        [DirtyPagesMB]              decimal(19,2) NOT NULL,

        CONSTRAINT [FK_perf_DatabaseMemorySnapshot_Batch]
            FOREIGN KEY ([SampleBatchId])
            REFERENCES [perf].[SampleBatch] ([SampleBatchId]),

        CONSTRAINT [FK_perf_DatabaseMemorySnapshot_Instance]
            FOREIGN KEY ([InstanceId])
            REFERENCES [dbo].[Instance] ([InstanceId])
    );

    CREATE UNIQUE INDEX [UX_perf_DatabaseMemorySnapshot_Batch_Db]
        ON [perf].[DatabaseMemorySnapshot] ([SampleBatchId], [DatabaseId]);

    CREATE INDEX [IX_perf_DatabaseMemorySnapshot_History]
        ON [perf].[DatabaseMemorySnapshot]
        (
            [InstanceId],
            [DatabaseName],
            [CapturedAt] DESC
        )
        INCLUDE ([BufferPoolMB], [DirtyPagesMB]);
END;
GO

/*=============================================================================
  05. Log / transactions snapshot
=============================================================================*/
IF OBJECT_ID(N'[perf].[DatabaseLogSnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [perf].[DatabaseLogSnapshot]
    (
        [DatabaseLogSnapshotId] bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT [PK_perf_DatabaseLogSnapshot] PRIMARY KEY,
        [SampleBatchId]          bigint NOT NULL,
        [InstanceId]             bigint NOT NULL,
        [CapturedAt]             datetime2(0) NOT NULL,
        [DatabaseName]           sysname NOT NULL,

        [TransactionsCounter]    bigint NULL,
        [LogBytesFlushedCounter] bigint NULL,
        [LogFlushesCounter]      bigint NULL,
        [LogFlushWaitsCounter]   bigint NULL,
        [LogFlushWaitTimeMs]     bigint NULL,
        [LogGrowthsCounter]      bigint NULL,
        [PercentLogUsed]         decimal(9,4) NULL,

        CONSTRAINT [FK_perf_DatabaseLogSnapshot_Batch]
            FOREIGN KEY ([SampleBatchId])
            REFERENCES [perf].[SampleBatch] ([SampleBatchId]),

        CONSTRAINT [FK_perf_DatabaseLogSnapshot_Instance]
            FOREIGN KEY ([InstanceId])
            REFERENCES [dbo].[Instance] ([InstanceId])
    );

    CREATE UNIQUE INDEX [UX_perf_DatabaseLogSnapshot_Batch_Db]
        ON [perf].[DatabaseLogSnapshot] ([SampleBatchId], [DatabaseName]);

    CREATE INDEX [IX_perf_DatabaseLogSnapshot_History]
        ON [perf].[DatabaseLogSnapshot]
        (
            [InstanceId],
            [DatabaseName],
            [CapturedAt] DESC
        )
        INCLUDE
        (
            [TransactionsCounter],
            [LogBytesFlushedCounter],
            [LogFlushesCounter],
            [LogFlushWaitTimeMs],
            [PercentLogUsed]
        );
END;
GO

/*=============================================================================
  06. Concurrency snapshot
=============================================================================*/
IF OBJECT_ID(N'[perf].[DatabaseConcurrencySnapshot]', N'U') IS NULL
BEGIN
    CREATE TABLE [perf].[DatabaseConcurrencySnapshot]
    (
        [DatabaseConcurrencySnapshotId] bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT [PK_perf_DatabaseConcurrencySnapshot] PRIMARY KEY,
        [SampleBatchId]                  bigint NOT NULL,
        [InstanceId]                     bigint NOT NULL,
        [CapturedAt]                     datetime2(0) NOT NULL,
        [DatabaseId]                     int NOT NULL,
        [DatabaseName]                   sysname NOT NULL,

        [ActiveRequests]                 int NOT NULL,
        [RunningRequests]                int NOT NULL,
        [SuspendedRequests]              int NOT NULL,
        [BlockedRequests]                int NOT NULL,
        [CurrentCpuMs]                   bigint NOT NULL,
        [CurrentElapsedMs]               bigint NOT NULL,
        [CurrentReads]                   bigint NOT NULL,
        [CurrentWrites]                  bigint NOT NULL,
        [CurrentLogicalReads]            bigint NOT NULL,
        [CurrentWaitMs]                  bigint NOT NULL,
        [LockWaitRequests]               int NOT NULL,
        [IoWaitRequests]                 int NOT NULL,

        CONSTRAINT [FK_perf_DatabaseConcurrencySnapshot_Batch]
            FOREIGN KEY ([SampleBatchId])
            REFERENCES [perf].[SampleBatch] ([SampleBatchId]),

        CONSTRAINT [FK_perf_DatabaseConcurrencySnapshot_Instance]
            FOREIGN KEY ([InstanceId])
            REFERENCES [dbo].[Instance] ([InstanceId])
    );

    CREATE UNIQUE INDEX [UX_perf_DatabaseConcurrencySnapshot_Batch_Db]
        ON [perf].[DatabaseConcurrencySnapshot] ([SampleBatchId], [DatabaseId]);

    CREATE INDEX [IX_perf_DatabaseConcurrencySnapshot_History]
        ON [perf].[DatabaseConcurrencySnapshot]
        (
            [InstanceId],
            [DatabaseName],
            [CapturedAt] DESC
        )
        INCLUDE
        (
            [ActiveRequests],
            [BlockedRequests],
            [CurrentCpuMs],
            [CurrentWaitMs],
            [LockWaitRequests],
            [IoWaitRequests]
        );
END;
GO

/*=============================================================================
  07. Collector lifecycle procedures
=============================================================================*/
CREATE OR ALTER PROCEDURE [perf].[usp_StartSampleBatch]
    @InstanceId bigint,
    @CollectorHost nvarchar(128) = NULL,
    @CollectorUser nvarchar(256) = NULL,
    @CollectorVersion varchar(20) = '1.0',
    @SampleBatchId bigint OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [dbo].[Instance]
        WHERE [InstanceId] = @InstanceId
    )
        THROW 51000, 'InstanceId does not exist in dbo.Instance.', 1;

    INSERT INTO [perf].[SampleBatch]
    (
        [InstanceId],
        [CapturedAt],
        [CollectorHost],
        [CollectorUser],
        [CollectorVersion],
        [CollectionStatus]
    )
    VALUES
    (
        @InstanceId,
        SYSDATETIME(),
        @CollectorHost,
        @CollectorUser,
        @CollectorVersion,
        'STARTED'
    );

    SET @SampleBatchId = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE [perf].[usp_FinishSampleBatch]
    @SampleBatchId bigint,
    @CollectionStatus varchar(20),
    @DurationMs int = NULL,
    @ErrorMessage nvarchar(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @CollectionStatus NOT IN ('SUCCESS','FAILED','PARTIAL')
        THROW 51001, 'Invalid collection status.', 1;

    UPDATE [perf].[SampleBatch]
    SET
        [CollectionStatus] = @CollectionStatus,
        [DurationMs] = @DurationMs,
        [ErrorMessage] = @ErrorMessage
    WHERE [SampleBatchId] = @SampleBatchId;

    IF @@ROWCOUNT = 0
        THROW 51002, 'SampleBatchId does not exist.', 1;
END;
GO

/*=============================================================================
  08. Report: database load ranking for a period
=============================================================================*/
CREATE OR ALTER PROCEDURE [perf].[usp_GetDatabaseLoadRanking]
    @ServerInstance nvarchar(256) = NULL,
    @InstanceId bigint = NULL,
    @From datetime2(0),
    @To datetime2(0),
    @Top int = 20
AS
BEGIN
    SET NOCOUNT ON;

    IF @From IS NULL OR @To IS NULL OR @From >= @To
        THROW 51010, 'Specify a valid @From / @To range.', 1;

    IF @Top IS NULL OR @Top < 1
        SET @Top = 20;

    IF @InstanceId IS NULL
    BEGIN
        SELECT @InstanceId = [InstanceId]
        FROM [dbo].[Instance]
        WHERE [ServerInstance] = @ServerInstance;
    END;

    IF @InstanceId IS NULL
        THROW 51011, 'Instance not found.', 1;

    /*
      Dla cumulative counters wybieramy pierwszy i ostatni sample w okresie.
      Jeśli licznik spadł (restart/eviction/reset), delta = NULL zamiast
      sztucznie ujemnej wartości.
    */
    ;WITH CpuRows AS
    (
        SELECT
            C.*,
            ROW_NUMBER() OVER
            (
                PARTITION BY C.[DatabaseName]
                ORDER BY C.[CapturedAt], C.[DatabaseCpuSnapshotId]
            ) AS rn_first,
            ROW_NUMBER() OVER
            (
                PARTITION BY C.[DatabaseName]
                ORDER BY C.[CapturedAt] DESC, C.[DatabaseCpuSnapshotId] DESC
            ) AS rn_last
        FROM [perf].[DatabaseCpuSnapshot] AS C
        INNER JOIN [perf].[SampleBatch] AS B
            ON B.[SampleBatchId] = C.[SampleBatchId]
        WHERE C.[InstanceId] = @InstanceId
          AND C.[CapturedAt] >= @From
          AND C.[CapturedAt] < @To
          AND B.[CollectionStatus] IN ('SUCCESS','PARTIAL')
    ),
    Cpu AS
    (
        SELECT
            [DatabaseName],
            MAX(CASE WHEN rn_first = 1 THEN [CpuMs] END) AS CpuFirst,
            MAX(CASE WHEN rn_last  = 1 THEN [CpuMs] END) AS CpuLast,
            MAX(CASE WHEN rn_first = 1 THEN [LogicalReads] END) AS LrFirst,
            MAX(CASE WHEN rn_last  = 1 THEN [LogicalReads] END) AS LrLast
        FROM CpuRows
        GROUP BY [DatabaseName]
    ),
    CpuDelta AS
    (
        SELECT
            [DatabaseName],
            CASE WHEN CpuLast >= CpuFirst THEN CpuLast - CpuFirst END AS CpuMsDelta,
            CASE WHEN LrLast >= LrFirst THEN LrLast - LrFirst END AS LogicalReadsDelta
        FROM Cpu
    ),
    IoRows AS
    (
        SELECT
            I.*,
            ROW_NUMBER() OVER
            (
                PARTITION BY I.[DatabaseName], I.[FileId]
                ORDER BY I.[CapturedAt], I.[FileIoSnapshotId]
            ) AS rn_first,
            ROW_NUMBER() OVER
            (
                PARTITION BY I.[DatabaseName], I.[FileId]
                ORDER BY I.[CapturedAt] DESC, I.[FileIoSnapshotId] DESC
            ) AS rn_last
        FROM [perf].[FileIoSnapshot] AS I
        INNER JOIN [perf].[SampleBatch] AS B
            ON B.[SampleBatchId] = I.[SampleBatchId]
        WHERE I.[InstanceId] = @InstanceId
          AND I.[CapturedAt] >= @From
          AND I.[CapturedAt] < @To
          AND B.[CollectionStatus] IN ('SUCCESS','PARTIAL')
    ),
    IoPerFile AS
    (
        SELECT
            [DatabaseName],
            [FileId],
            MAX(CASE WHEN rn_first = 1 THEN [NumOfBytesRead] END) AS ReadFirst,
            MAX(CASE WHEN rn_last  = 1 THEN [NumOfBytesRead] END) AS ReadLast,
            MAX(CASE WHEN rn_first = 1 THEN [NumOfBytesWritten] END) AS WriteFirst,
            MAX(CASE WHEN rn_last  = 1 THEN [NumOfBytesWritten] END) AS WriteLast,
            MAX(CASE WHEN rn_first = 1 THEN [NumOfReads] END) AS ReadsFirst,
            MAX(CASE WHEN rn_last  = 1 THEN [NumOfReads] END) AS ReadsLast,
            MAX(CASE WHEN rn_first = 1 THEN [IoStallReadMs] END) AS ReadStallFirst,
            MAX(CASE WHEN rn_last  = 1 THEN [IoStallReadMs] END) AS ReadStallLast,
            MAX(CASE WHEN rn_first = 1 THEN [NumOfWrites] END) AS WritesFirst,
            MAX(CASE WHEN rn_last  = 1 THEN [NumOfWrites] END) AS WritesLast,
            MAX(CASE WHEN rn_first = 1 THEN [IoStallWriteMs] END) AS WriteStallFirst,
            MAX(CASE WHEN rn_last  = 1 THEN [IoStallWriteMs] END) AS WriteStallLast
        FROM IoRows
        GROUP BY [DatabaseName], [FileId]
    ),
    Io AS
    (
        SELECT
            [DatabaseName],
            SUM(CASE WHEN ReadLast >= ReadFirst THEN ReadLast - ReadFirst END) AS ReadBytesDelta,
            SUM(CASE WHEN WriteLast >= WriteFirst THEN WriteLast - WriteFirst END) AS WriteBytesDelta,
            SUM(CASE WHEN ReadsLast >= ReadsFirst THEN ReadsLast - ReadsFirst END) AS ReadsDelta,
            SUM(CASE WHEN ReadStallLast >= ReadStallFirst THEN ReadStallLast - ReadStallFirst END) AS ReadStallDelta,
            SUM(CASE WHEN WritesLast >= WritesFirst THEN WritesLast - WritesFirst END) AS WritesDelta,
            SUM(CASE WHEN WriteStallLast >= WriteStallFirst THEN WriteStallLast - WriteStallFirst END) AS WriteStallDelta
        FROM IoPerFile
        GROUP BY [DatabaseName]
    ),
    Mem AS
    (
        SELECT
            M.[DatabaseName],
            AVG(CONVERT(decimal(19,2), M.[BufferPoolMB])) AS AvgBufferPoolMB,
            MAX(M.[BufferPoolMB]) AS MaxBufferPoolMB
        FROM [perf].[DatabaseMemorySnapshot] AS M
        INNER JOIN [perf].[SampleBatch] AS B
            ON B.[SampleBatchId] = M.[SampleBatchId]
        WHERE M.[InstanceId] = @InstanceId
          AND M.[CapturedAt] >= @From
          AND M.[CapturedAt] < @To
          AND B.[CollectionStatus] IN ('SUCCESS','PARTIAL')
        GROUP BY M.[DatabaseName]
    ),
    Concurrency AS
    (
        SELECT
            C.[DatabaseName],
            AVG(CONVERT(decimal(19,2), C.[ActiveRequests])) AS AvgActiveRequests,
            MAX(C.[ActiveRequests]) AS MaxActiveRequests,
            AVG(CONVERT(decimal(19,2), C.[BlockedRequests])) AS AvgBlockedRequests,
            MAX(C.[BlockedRequests]) AS MaxBlockedRequests,
            AVG(CONVERT(decimal(19,2), C.[CurrentWaitMs])) AS AvgCurrentWaitMs
        FROM [perf].[DatabaseConcurrencySnapshot] AS C
        INNER JOIN [perf].[SampleBatch] AS B
            ON B.[SampleBatchId] = C.[SampleBatchId]
        WHERE C.[InstanceId] = @InstanceId
          AND C.[CapturedAt] >= @From
          AND C.[CapturedAt] < @To
          AND B.[CollectionStatus] IN ('SUCCESS','PARTIAL')
        GROUP BY C.[DatabaseName]
    ),
    LogRows AS
    (
        SELECT
            L.*,
            ROW_NUMBER() OVER
            (
                PARTITION BY L.[DatabaseName]
                ORDER BY L.[CapturedAt], L.[DatabaseLogSnapshotId]
            ) AS rn_first,
            ROW_NUMBER() OVER
            (
                PARTITION BY L.[DatabaseName]
                ORDER BY L.[CapturedAt] DESC, L.[DatabaseLogSnapshotId] DESC
            ) AS rn_last
        FROM [perf].[DatabaseLogSnapshot] AS L
        INNER JOIN [perf].[SampleBatch] AS B
            ON B.[SampleBatchId] = L.[SampleBatchId]
        WHERE L.[InstanceId] = @InstanceId
          AND L.[CapturedAt] >= @From
          AND L.[CapturedAt] < @To
          AND B.[CollectionStatus] IN ('SUCCESS','PARTIAL')
    ),
    LogAgg AS
    (
        SELECT
            [DatabaseName],
            MAX(CASE WHEN rn_first = 1 THEN [TransactionsCounter] END) AS TxFirst,
            MAX(CASE WHEN rn_last  = 1 THEN [TransactionsCounter] END) AS TxLast,
            MAX(CASE WHEN rn_first = 1 THEN [LogBytesFlushedCounter] END) AS LogBytesFirst,
            MAX(CASE WHEN rn_last  = 1 THEN [LogBytesFlushedCounter] END) AS LogBytesLast,
            AVG([PercentLogUsed]) AS AvgPercentLogUsed,
            MAX([PercentLogUsed]) AS MaxPercentLogUsed
        FROM LogRows
        GROUP BY [DatabaseName]
    ),
    LogDelta AS
    (
        SELECT
            [DatabaseName],
            CASE WHEN TxLast >= TxFirst THEN TxLast - TxFirst END AS TransactionsDelta,
            CASE WHEN LogBytesLast >= LogBytesFirst THEN LogBytesLast - LogBytesFirst END AS LogBytesDelta,
            AvgPercentLogUsed,
            MaxPercentLogUsed
        FROM LogAgg
    ),
    DbNames AS
    (
        SELECT [DatabaseName] FROM CpuDelta
        UNION
        SELECT [DatabaseName] FROM Io
        UNION
        SELECT [DatabaseName] FROM Mem
        UNION
        SELECT [DatabaseName] FROM Concurrency
        UNION
        SELECT [DatabaseName] FROM LogDelta
    ),
    Combined AS
    (
        SELECT
            D.[DatabaseName],
            C.[CpuMsDelta],
            C.[LogicalReadsDelta],
            I.[ReadBytesDelta],
            I.[WriteBytesDelta],
            CAST(I.[ReadBytesDelta] / 1048576.0 AS decimal(19,2)) AS ReadMB,
            CAST(I.[WriteBytesDelta] / 1048576.0 AS decimal(19,2)) AS WriteMB,
            CAST(
                CASE WHEN I.[ReadsDelta] > 0
                     THEN 1.0 * I.[ReadStallDelta] / I.[ReadsDelta]
                END AS decimal(19,2)
            ) AS AvgReadLatencyMs,
            CAST(
                CASE WHEN I.[WritesDelta] > 0
                     THEN 1.0 * I.[WriteStallDelta] / I.[WritesDelta]
                END AS decimal(19,2)
            ) AS AvgWriteLatencyMs,
            M.[AvgBufferPoolMB],
            M.[MaxBufferPoolMB],
            L.[TransactionsDelta],
            CAST(L.[LogBytesDelta] / 1048576.0 AS decimal(19,2)) AS LogMB,
            L.[AvgPercentLogUsed],
            L.[MaxPercentLogUsed],
            X.[AvgActiveRequests],
            X.[MaxActiveRequests],
            X.[AvgBlockedRequests],
            X.[MaxBlockedRequests],
            X.[AvgCurrentWaitMs]
        FROM DbNames AS D
        LEFT JOIN CpuDelta AS C ON C.[DatabaseName] = D.[DatabaseName]
        LEFT JOIN Io AS I ON I.[DatabaseName] = D.[DatabaseName]
        LEFT JOIN Mem AS M ON M.[DatabaseName] = D.[DatabaseName]
        LEFT JOIN LogDelta AS L ON L.[DatabaseName] = D.[DatabaseName]
        LEFT JOIN Concurrency AS X ON X.[DatabaseName] = D.[DatabaseName]
    ),
    Totals AS
    (
        SELECT
            SUM(ISNULL([CpuMsDelta],0)) AS TotalCpu,
            SUM(ISNULL([ReadBytesDelta],0)) AS TotalReadBytes,
            SUM(ISNULL([WriteBytesDelta],0)) AS TotalWriteBytes,
            SUM(ISNULL([AvgBufferPoolMB],0)) AS TotalAvgBufferPoolMB,
            SUM(ISNULL([TransactionsDelta],0)) AS TotalTransactions,
            SUM(ISNULL([MaxBlockedRequests],0)) AS TotalMaxBlocked
        FROM Combined
    )
    SELECT TOP (@Top)
        I.[ServerInstance],
        C.[DatabaseName],

        C.[CpuMsDelta],
        CAST(
            100.0 * C.[CpuMsDelta] / NULLIF(T.[TotalCpu],0)
            AS decimal(9,2)
        ) AS [CpuSharePct],

        C.[ReadMB],
        CAST(
            100.0 * C.[ReadBytesDelta] / NULLIF(T.[TotalReadBytes],0)
            AS decimal(9,2)
        ) AS [ReadSharePct],

        C.[WriteMB],
        CAST(
            100.0 * C.[WriteBytesDelta] / NULLIF(T.[TotalWriteBytes],0)
            AS decimal(9,2)
        ) AS [WriteSharePct],

        C.[AvgReadLatencyMs],
        C.[AvgWriteLatencyMs],

        C.[AvgBufferPoolMB],
        C.[MaxBufferPoolMB],
        CAST(
            100.0 * C.[AvgBufferPoolMB] / NULLIF(T.[TotalAvgBufferPoolMB],0)
            AS decimal(9,2)
        ) AS [BufferPoolSharePct],

        C.[TransactionsDelta],
        CAST(
            100.0 * C.[TransactionsDelta] / NULLIF(T.[TotalTransactions],0)
            AS decimal(9,2)
        ) AS [TransactionsSharePct],

        C.[LogMB],
        C.[AvgPercentLogUsed],
        C.[MaxPercentLogUsed],

        C.[AvgActiveRequests],
        C.[MaxActiveRequests],
        C.[AvgBlockedRequests],
        C.[MaxBlockedRequests],
        CAST(
            100.0 * C.[MaxBlockedRequests] / NULLIF(T.[TotalMaxBlocked],0)
            AS decimal(9,2)
        ) AS [BlockingSharePct],
        C.[AvgCurrentWaitMs],

        CASE
            WHEN ISNULL(100.0 * C.[CpuMsDelta] / NULLIF(T.[TotalCpu],0),0)
               >= ISNULL(100.0 * C.[ReadBytesDelta] / NULLIF(T.[TotalReadBytes],0),0)
             AND ISNULL(100.0 * C.[CpuMsDelta] / NULLIF(T.[TotalCpu],0),0)
               >= ISNULL(100.0 * C.[WriteBytesDelta] / NULLIF(T.[TotalWriteBytes],0),0)
                THEN 'CPU'
            WHEN ISNULL(100.0 * C.[ReadBytesDelta] / NULLIF(T.[TotalReadBytes],0),0)
               >= ISNULL(100.0 * C.[WriteBytesDelta] / NULLIF(T.[TotalWriteBytes],0),0)
                THEN 'READ'
            ELSE 'WRITE'
        END AS [DominantResource],

        CAST(
            CASE
                WHEN ISNULL(100.0 * C.[CpuMsDelta] / NULLIF(T.[TotalCpu],0),0)
                   >= ISNULL(100.0 * C.[ReadBytesDelta] / NULLIF(T.[TotalReadBytes],0),0)
                 AND ISNULL(100.0 * C.[CpuMsDelta] / NULLIF(T.[TotalCpu],0),0)
                   >= ISNULL(100.0 * C.[WriteBytesDelta] / NULLIF(T.[TotalWriteBytes],0),0)
                    THEN ISNULL(100.0 * C.[CpuMsDelta] / NULLIF(T.[TotalCpu],0),0)
                WHEN ISNULL(100.0 * C.[ReadBytesDelta] / NULLIF(T.[TotalReadBytes],0),0)
                   >= ISNULL(100.0 * C.[WriteBytesDelta] / NULLIF(T.[TotalWriteBytes],0),0)
                    THEN ISNULL(100.0 * C.[ReadBytesDelta] / NULLIF(T.[TotalReadBytes],0),0)
                ELSE ISNULL(100.0 * C.[WriteBytesDelta] / NULLIF(T.[TotalWriteBytes],0),0)
            END
            AS decimal(9,2)
        ) AS [DominantResourceSharePct]
    FROM Combined AS C
    CROSS JOIN Totals AS T
    INNER JOIN [dbo].[Instance] AS I
        ON I.[InstanceId] = @InstanceId
    ORDER BY
        [DominantResourceSharePct] DESC,
        C.[DatabaseName];
END;
GO

/*=============================================================================
  09. Focused Top procedures
=============================================================================*/

CREATE OR ALTER PROCEDURE [perf].[usp_GetTopDatabasesByCpu]
    @ServerInstance nvarchar(256) = NULL,
    @InstanceId bigint = NULL,
    @From datetime2(0),
    @To datetime2(0),
    @Top int = 20
AS
BEGIN
    SET NOCOUNT ON;

    IF @InstanceId IS NULL
        SELECT @InstanceId = [InstanceId]
        FROM [dbo].[Instance]
        WHERE [ServerInstance] = @ServerInstance;

    ;WITH X AS
    (
        SELECT
            C.*,
            ROW_NUMBER() OVER
            (
                PARTITION BY C.DatabaseName
                ORDER BY C.CapturedAt, C.DatabaseCpuSnapshotId
            ) AS rn_first,
            ROW_NUMBER() OVER
            (
                PARTITION BY C.DatabaseName
                ORDER BY C.CapturedAt DESC, C.DatabaseCpuSnapshotId DESC
            ) AS rn_last
        FROM perf.DatabaseCpuSnapshot AS C
        INNER JOIN perf.SampleBatch AS B
            ON B.SampleBatchId = C.SampleBatchId
        WHERE C.InstanceId = @InstanceId
          AND C.CapturedAt >= @From
          AND C.CapturedAt < @To
          AND B.CollectionStatus IN ('SUCCESS','PARTIAL')
    ),
    D AS
    (
        SELECT
            DatabaseName,
            MAX(CASE WHEN rn_first = 1 THEN CpuMs END) AS FirstCpuMs,
            MAX(CASE WHEN rn_last = 1 THEN CpuMs END) AS LastCpuMs,
            MAX(CASE WHEN rn_first = 1 THEN ExecutionCount END) AS FirstExec,
            MAX(CASE WHEN rn_last = 1 THEN ExecutionCount END) AS LastExec
        FROM X
        GROUP BY DatabaseName
    ),
    R AS
    (
        SELECT
            DatabaseName,
            CASE WHEN LastCpuMs >= FirstCpuMs THEN LastCpuMs - FirstCpuMs END AS CpuMsDelta,
            CASE WHEN LastExec >= FirstExec THEN LastExec - FirstExec END AS ExecutionCountDelta
        FROM D
    )
    SELECT TOP (@Top)
        I.ServerInstance,
        R.DatabaseName,
        R.CpuMsDelta,
        R.ExecutionCountDelta,
        CAST(
            100.0 * R.CpuMsDelta /
            NULLIF(SUM(ISNULL(R.CpuMsDelta,0)) OVER (),0)
            AS decimal(9,2)
        ) AS CpuSharePct
    FROM R
    INNER JOIN dbo.Instance AS I
        ON I.InstanceId = @InstanceId
    ORDER BY R.CpuMsDelta DESC, R.DatabaseName;
END;
GO

CREATE OR ALTER PROCEDURE [perf].[usp_GetTopDatabasesByIo]
    @ServerInstance nvarchar(256) = NULL,
    @InstanceId bigint = NULL,
    @From datetime2(0),
    @To datetime2(0),
    @Top int = 20
AS
BEGIN
    SET NOCOUNT ON;

    IF @InstanceId IS NULL
        SELECT @InstanceId = [InstanceId]
        FROM [dbo].[Instance]
        WHERE [ServerInstance] = @ServerInstance;

    ;WITH X AS
    (
        SELECT
            F.*,
            ROW_NUMBER() OVER
            (
                PARTITION BY F.DatabaseName, F.FileId
                ORDER BY F.CapturedAt, F.FileIoSnapshotId
            ) AS rn_first,
            ROW_NUMBER() OVER
            (
                PARTITION BY F.DatabaseName, F.FileId
                ORDER BY F.CapturedAt DESC, F.FileIoSnapshotId DESC
            ) AS rn_last
        FROM perf.FileIoSnapshot AS F
        INNER JOIN perf.SampleBatch AS B
            ON B.SampleBatchId = F.SampleBatchId
        WHERE F.InstanceId = @InstanceId
          AND F.CapturedAt >= @From
          AND F.CapturedAt < @To
          AND B.CollectionStatus IN ('SUCCESS','PARTIAL')
    ),
    PF AS
    (
        SELECT
            DatabaseName,
            FileId,
            MAX(CASE WHEN rn_first = 1 THEN NumOfBytesRead END) AS ReadFirst,
            MAX(CASE WHEN rn_last = 1 THEN NumOfBytesRead END) AS ReadLast,
            MAX(CASE WHEN rn_first = 1 THEN NumOfBytesWritten END) AS WriteFirst,
            MAX(CASE WHEN rn_last = 1 THEN NumOfBytesWritten END) AS WriteLast,
            MAX(CASE WHEN rn_first = 1 THEN NumOfReads END) AS ReadsFirst,
            MAX(CASE WHEN rn_last = 1 THEN NumOfReads END) AS ReadsLast,
            MAX(CASE WHEN rn_first = 1 THEN IoStallReadMs END) AS ReadStallFirst,
            MAX(CASE WHEN rn_last = 1 THEN IoStallReadMs END) AS ReadStallLast,
            MAX(CASE WHEN rn_first = 1 THEN NumOfWrites END) AS WritesFirst,
            MAX(CASE WHEN rn_last = 1 THEN NumOfWrites END) AS WritesLast,
            MAX(CASE WHEN rn_first = 1 THEN IoStallWriteMs END) AS WriteStallFirst,
            MAX(CASE WHEN rn_last = 1 THEN IoStallWriteMs END) AS WriteStallLast
        FROM X
        GROUP BY DatabaseName, FileId
    ),
    R AS
    (
        SELECT
            DatabaseName,
            SUM(CASE WHEN ReadLast >= ReadFirst THEN ReadLast - ReadFirst END) AS ReadBytesDelta,
            SUM(CASE WHEN WriteLast >= WriteFirst THEN WriteLast - WriteFirst END) AS WriteBytesDelta,
            SUM(CASE WHEN ReadsLast >= ReadsFirst THEN ReadsLast - ReadsFirst END) AS ReadsDelta,
            SUM(CASE WHEN ReadStallLast >= ReadStallFirst THEN ReadStallLast - ReadStallFirst END) AS ReadStallDelta,
            SUM(CASE WHEN WritesLast >= WritesFirst THEN WritesLast - WritesFirst END) AS WritesDelta,
            SUM(CASE WHEN WriteStallLast >= WriteStallFirst THEN WriteStallLast - WriteStallFirst END) AS WriteStallDelta
        FROM PF
        GROUP BY DatabaseName
    )
    SELECT TOP (@Top)
        I.ServerInstance,
        R.DatabaseName,
        CAST(R.ReadBytesDelta / 1048576.0 AS decimal(19,2)) AS ReadMB,
        CAST(R.WriteBytesDelta / 1048576.0 AS decimal(19,2)) AS WriteMB,
        CAST(
            CASE WHEN R.ReadsDelta > 0
                 THEN 1.0 * R.ReadStallDelta / R.ReadsDelta END
            AS decimal(19,2)
        ) AS AvgReadLatencyMs,
        CAST(
            CASE WHEN R.WritesDelta > 0
                 THEN 1.0 * R.WriteStallDelta / R.WritesDelta END
            AS decimal(19,2)
        ) AS AvgWriteLatencyMs
    FROM R
    INNER JOIN dbo.Instance AS I
        ON I.InstanceId = @InstanceId
    ORDER BY
        ISNULL(R.ReadBytesDelta,0) + ISNULL(R.WriteBytesDelta,0) DESC,
        R.DatabaseName;
END;
GO

CREATE OR ALTER PROCEDURE [perf].[usp_GetTopDatabasesByMemory]
    @ServerInstance nvarchar(256) = NULL,
    @InstanceId bigint = NULL,
    @From datetime2(0),
    @To datetime2(0),
    @Top int = 20
AS
BEGIN
    SET NOCOUNT ON;

    IF @InstanceId IS NULL
        SELECT @InstanceId = [InstanceId]
        FROM [dbo].[Instance]
        WHERE [ServerInstance] = @ServerInstance;

    SELECT TOP (@Top)
        I.[ServerInstance],
        M.[DatabaseName],
        CAST(AVG(M.[BufferPoolMB]) AS decimal(19,2)) AS AvgBufferPoolMB,
        MAX(M.[BufferPoolMB]) AS MaxBufferPoolMB,
        CAST(AVG(M.[DirtyPagesMB]) AS decimal(19,2)) AS AvgDirtyPagesMB
    FROM [perf].[DatabaseMemorySnapshot] AS M
    INNER JOIN [dbo].[Instance] AS I
        ON I.[InstanceId] = M.[InstanceId]
    INNER JOIN [perf].[SampleBatch] AS B
        ON B.[SampleBatchId] = M.[SampleBatchId]
    WHERE M.[InstanceId] = @InstanceId
      AND M.[CapturedAt] >= @From
      AND M.[CapturedAt] < @To
      AND B.[CollectionStatus] IN ('SUCCESS','PARTIAL')
    GROUP BY I.[ServerInstance], M.[DatabaseName]
    ORDER BY AvgBufferPoolMB DESC;
END;
GO

CREATE OR ALTER PROCEDURE [perf].[usp_GetTopDatabasesByBlocking]
    @ServerInstance nvarchar(256) = NULL,
    @InstanceId bigint = NULL,
    @From datetime2(0),
    @To datetime2(0),
    @Top int = 20
AS
BEGIN
    SET NOCOUNT ON;

    IF @InstanceId IS NULL
        SELECT @InstanceId = [InstanceId]
        FROM [dbo].[Instance]
        WHERE [ServerInstance] = @ServerInstance;

    SELECT TOP (@Top)
        I.[ServerInstance],
        C.[DatabaseName],
        CAST(AVG(CONVERT(decimal(19,2),C.[BlockedRequests])) AS decimal(19,2)) AS AvgBlockedRequests,
        MAX(C.[BlockedRequests]) AS MaxBlockedRequests,
        CAST(AVG(CONVERT(decimal(19,2),C.[ActiveRequests])) AS decimal(19,2)) AS AvgActiveRequests,
        MAX(C.[CurrentWaitMs]) AS MaxCurrentWaitMs,
        SUM(CONVERT(bigint,C.[LockWaitRequests])) AS ObservedLockWaitRequests
    FROM [perf].[DatabaseConcurrencySnapshot] AS C
    INNER JOIN [dbo].[Instance] AS I
        ON I.[InstanceId] = C.[InstanceId]
    INNER JOIN [perf].[SampleBatch] AS B
        ON B.[SampleBatchId] = C.[SampleBatchId]
    WHERE C.[InstanceId] = @InstanceId
      AND C.[CapturedAt] >= @From
      AND C.[CapturedAt] < @To
      AND B.[CollectionStatus] IN ('SUCCESS','PARTIAL')
    GROUP BY I.[ServerInstance], C.[DatabaseName]
    ORDER BY MaxBlockedRequests DESC, AvgBlockedRequests DESC;
END;
GO

/*=============================================================================
  10. Current-state view
=============================================================================*/
CREATE OR ALTER VIEW [perf].[vLatestDatabaseResourceSample]
AS
WITH LatestBatch AS
(
    SELECT
        [InstanceId],
        MAX([SampleBatchId]) AS [SampleBatchId]
    FROM [perf].[SampleBatch]
    WHERE [CollectionStatus] IN ('SUCCESS','PARTIAL')
    GROUP BY [InstanceId]
),
Io AS
(
    SELECT
        F.[SampleBatchId],
        F.[InstanceId],
        F.[DatabaseName],
        SUM(F.[NumOfBytesRead]) AS [NumOfBytesRead],
        SUM(F.[NumOfBytesWritten]) AS [NumOfBytesWritten]
    FROM [perf].[FileIoSnapshot] AS F
    INNER JOIN LatestBatch AS L
        ON L.[SampleBatchId] = F.[SampleBatchId]
       AND L.[InstanceId] = F.[InstanceId]
    GROUP BY F.[SampleBatchId], F.[InstanceId], F.[DatabaseName]
),
DbNames AS
(
    SELECT C.[SampleBatchId], C.[InstanceId], C.[DatabaseName]
    FROM [perf].[DatabaseCpuSnapshot] AS C
    INNER JOIN LatestBatch AS L ON L.[SampleBatchId] = C.[SampleBatchId]
    UNION
    SELECT M.[SampleBatchId], M.[InstanceId], M.[DatabaseName]
    FROM [perf].[DatabaseMemorySnapshot] AS M
    INNER JOIN LatestBatch AS L ON L.[SampleBatchId] = M.[SampleBatchId]
    UNION
    SELECT X.[SampleBatchId], X.[InstanceId], X.[DatabaseName]
    FROM [perf].[DatabaseConcurrencySnapshot] AS X
    INNER JOIN LatestBatch AS L ON L.[SampleBatchId] = X.[SampleBatchId]
)
SELECT
    D.[SampleBatchId],
    D.[InstanceId],
    I.[ServerInstance],
    B.[CapturedAt],
    D.[DatabaseName],
    C.[CpuMs],
    C.[ExecutionCount],
    C.[LogicalReads],
    IO.[NumOfBytesRead],
    IO.[NumOfBytesWritten],
    M.[BufferPoolMB],
    M.[DirtyPagesMB],
    X.[ActiveRequests],
    X.[BlockedRequests],
    X.[CurrentWaitMs]
FROM DbNames AS D
INNER JOIN [dbo].[Instance] AS I
    ON I.[InstanceId] = D.[InstanceId]
INNER JOIN [perf].[SampleBatch] AS B
    ON B.[SampleBatchId] = D.[SampleBatchId]
LEFT JOIN [perf].[DatabaseCpuSnapshot] AS C
    ON C.[SampleBatchId] = D.[SampleBatchId]
   AND C.[InstanceId] = D.[InstanceId]
   AND C.[DatabaseName] = D.[DatabaseName]
LEFT JOIN Io AS IO
    ON IO.[SampleBatchId] = D.[SampleBatchId]
   AND IO.[InstanceId] = D.[InstanceId]
   AND IO.[DatabaseName] = D.[DatabaseName]
LEFT JOIN [perf].[DatabaseMemorySnapshot] AS M
    ON M.[SampleBatchId] = D.[SampleBatchId]
   AND M.[InstanceId] = D.[InstanceId]
   AND M.[DatabaseName] = D.[DatabaseName]
LEFT JOIN [perf].[DatabaseConcurrencySnapshot] AS X
    ON X.[SampleBatchId] = D.[SampleBatchId]
   AND X.[InstanceId] = D.[InstanceId]
   AND X.[DatabaseName] = D.[DatabaseName];
GO

/*=============================================================================
  11. Retention
=============================================================================*/
/*
Retencja jest instalowana osobnym plikiem:
    21_Create_Perf_Retention.sql
*/
PRINT 'DBACentralRepository PERF module v1.0 installed.';
GO
