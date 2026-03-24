/* ============================================================
   SqlStressLab - baza i obiekty demo
   Sprint 1 -> Sprint 6
   Autor: SQLManiak
   SQL Server 2022 / kompatybilne z 2016+
   ============================================================ */

SET NOCOUNT ON;
GO

/* ============================================================
   1. CREATE DATABASE
   ============================================================ */
IF DB_ID(N'StressLabDb') IS NULL
BEGIN
    CREATE DATABASE StressLabDb;
END
GO

USE StressLabDb;
GO

/* ============================================================
   2. CORE TABLES
   ============================================================ */

/* ---------- StressRun ---------- */
IF OBJECT_ID(N'dbo.StressRun', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.StressRun
    (
        RunId                nvarchar(50)   NOT NULL CONSTRAINT PK_StressRun PRIMARY KEY,
        ProfileName          nvarchar(200)  NOT NULL,
        ScenarioName         nvarchar(100)  NOT NULL,
        TagsCsv              nvarchar(1000) NULL,
        EnvironmentName      nvarchar(200)  NULL,
        MachineName          nvarchar(200)  NULL,
        OsVersion            nvarchar(500)  NULL,
        DotNetVersion        nvarchar(100)  NULL,

        ServerName           nvarchar(200)  NOT NULL,
        DatabaseName         nvarchar(200)  NOT NULL,
        CommandType          nvarchar(50)   NOT NULL,
        ExecutionMode        nvarchar(50)   NOT NULL,

        Workers              int            NOT NULL,
        IterationsPerWorker  int            NOT NULL,

        TotalExecutions      int            NOT NULL,
        SuccessCount         int            NOT NULL,
        ErrorCount           int            NOT NULL,
        RetryCount           int            NOT NULL,

        AvgDurationMs        float          NOT NULL,
        MinDurationMs        bigint         NOT NULL,
        P50DurationMs        bigint         NOT NULL,
        P95DurationMs        bigint         NOT NULL,
        P99DurationMs        bigint         NOT NULL,
        MaxDurationMs        bigint         NOT NULL,
        ThroughputPerSecond  float          NOT NULL,

        StartedAtUtc         datetime2(3)   NOT NULL,
        FinishedAtUtc        datetime2(3)   NOT NULL,
        WallClockMs          bigint         NOT NULL,

        SqlProductVersion    nvarchar(100)  NULL,
        SqlProductLevel      nvarchar(100)  NULL,
        SqlEdition           nvarchar(200)  NULL,
        SqlEngineEdition     nvarchar(100)  NULL,
        SqlInstanceName      nvarchar(200)  NULL,
        SqlCompatibilityLevel int           NULL
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StressRun_ProfileName_StartedAtUtc' AND object_id = OBJECT_ID(N'dbo.StressRun'))
BEGIN
    CREATE INDEX IX_StressRun_ProfileName_StartedAtUtc
        ON dbo.StressRun(ProfileName, StartedAtUtc DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StressRun_ScenarioName_StartedAtUtc' AND object_id = OBJECT_ID(N'dbo.StressRun'))
BEGIN
    CREATE INDEX IX_StressRun_ScenarioName_StartedAtUtc
        ON dbo.StressRun(ScenarioName, StartedAtUtc DESC);
END
GO

/* ---------- StressRunSample ---------- */
IF OBJECT_ID(N'dbo.StressRunSample', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.StressRunSample
    (
        StressRunSampleId    bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_StressRunSample PRIMARY KEY,
        RunId                nvarchar(50)   NOT NULL,
        WorkerId             int            NOT NULL,
        Iteration            int            NOT NULL,
        StartedAtUtc         datetime2(3)   NOT NULL,
        DurationMs           bigint         NOT NULL,
        Success              bit            NOT NULL,
        RetryAttempt         int            NOT NULL,
        ErrorCategory        nvarchar(100)  NULL,
        SqlErrorNumber       int            NULL,
        ErrorMessage         nvarchar(max)  NULL,
        ScalarValue          nvarchar(4000) NULL,
        ReaderRowCount       int            NULL,

        Spid                 int            NULL,
        HostName             nvarchar(256)  NULL,
        AppName              nvarchar(256)  NULL,
        LoginName            nvarchar(256)  NULL,
        DatabaseName         nvarchar(256)  NULL
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_StressRunSample_StressRun')
BEGIN
    ALTER TABLE dbo.StressRunSample
    ADD CONSTRAINT FK_StressRunSample_StressRun
        FOREIGN KEY (RunId) REFERENCES dbo.StressRun(RunId);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StressRunSample_RunId' AND object_id = OBJECT_ID(N'dbo.StressRunSample'))
BEGIN
    CREATE INDEX IX_StressRunSample_RunId
        ON dbo.StressRunSample(RunId);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StressRunSample_RunId_WorkerId_Iteration' AND object_id = OBJECT_ID(N'dbo.StressRunSample'))
BEGIN
    CREATE INDEX IX_StressRunSample_RunId_WorkerId_Iteration
        ON dbo.StressRunSample(RunId, WorkerId, Iteration);
END
GO

/* ---------- StressRunDmvSnapshot ---------- */
IF OBJECT_ID(N'dbo.StressRunDmvSnapshot', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.StressRunDmvSnapshot
    (
        StressRunDmvSnapshotId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_StressRunDmvSnapshot PRIMARY KEY,
        RunId                  nvarchar(50)   NOT NULL,
        SnapshotPhase          nvarchar(50)   NOT NULL,
        SnapshotName           nvarchar(100)  NOT NULL,
        CollectedAtUtc         datetime2(3)   NOT NULL,
        RowJson                nvarchar(max)  NOT NULL
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_StressRunDmvSnapshot_StressRun')
BEGIN
    ALTER TABLE dbo.StressRunDmvSnapshot
    ADD CONSTRAINT FK_StressRunDmvSnapshot_StressRun
        FOREIGN KEY (RunId) REFERENCES dbo.StressRun(RunId);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StressRunDmvSnapshot_RunId' AND object_id = OBJECT_ID(N'dbo.StressRunDmvSnapshot'))
BEGIN
    CREATE INDEX IX_StressRunDmvSnapshot_RunId
        ON dbo.StressRunDmvSnapshot(RunId);
END
GO

/* ---------- StressRunComparison ---------- */
IF OBJECT_ID(N'dbo.StressRunComparison', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.StressRunComparison
    (
        StressRunComparisonId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_StressRunComparison PRIMARY KEY,
        RunId                 nvarchar(50) NOT NULL,
        BaselineRunId         nvarchar(50) NOT NULL,
        AvgDurationDeltaMs    float        NOT NULL,
        P95DurationDeltaMs    bigint       NOT NULL,
        ThroughputDelta       float        NOT NULL,
        ErrorCountDelta       int          NOT NULL,
        RetryCountDelta       int          NOT NULL,
        IsRegression          bit          NOT NULL,
        ComparedAtUtc         datetime2(3) NOT NULL
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_StressRunComparison_Run')
BEGIN
    ALTER TABLE dbo.StressRunComparison
    ADD CONSTRAINT FK_StressRunComparison_Run
        FOREIGN KEY (RunId) REFERENCES dbo.StressRun(RunId);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StressRunComparison_RunId' AND object_id = OBJECT_ID(N'dbo.StressRunComparison'))
BEGIN
    CREATE INDEX IX_StressRunComparison_RunId
        ON dbo.StressRunComparison(RunId);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StressRunComparison_BaselineRunId' AND object_id = OBJECT_ID(N'dbo.StressRunComparison'))
BEGIN
    CREATE INDEX IX_StressRunComparison_BaselineRunId
        ON dbo.StressRunComparison(BaselineRunId);
END
GO

/* ============================================================
   3. DEMO OBJECTS - SPRINT 1/2
   ============================================================ */

/* ---------- DemoProcTarget ---------- */
IF OBJECT_ID(N'dbo.DemoProcTarget', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DemoProcTarget
    (
        Id           int           NOT NULL CONSTRAINT PK_DemoProcTarget PRIMARY KEY,
        CounterValue int           NOT NULL,
        UpdatedAt    datetime2(3)  NOT NULL
    );

    ;WITH N AS
    (
        SELECT TOP (100)
               ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects
    )
    INSERT INTO dbo.DemoProcTarget(Id, CounterValue, UpdatedAt)
    SELECT n, 0, SYSUTCDATETIME()
    FROM N;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_DemoProc
    @Id int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE dbo.DemoProcTarget
    SET CounterValue = CounterValue + 1,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @Id;
END
GO

/* ============================================================
   4. DEMO OBJECTS - BLOCKING (SPRINT 2/3/4)
   ============================================================ */

IF OBJECT_ID(N'dbo.BlockingDemo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BlockingDemo
    (
        Id           int           NOT NULL CONSTRAINT PK_BlockingDemo PRIMARY KEY,
        CounterValue int           NOT NULL,
        UpdatedAt    datetime2(3)  NOT NULL
    );

    INSERT INTO dbo.BlockingDemo (Id, CounterValue, UpdatedAt)
    VALUES (1, 0, SYSUTCDATETIME());
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_BlockingDemo
    @Id int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

    UPDATE dbo.BlockingDemo
    SET CounterValue = CounterValue + 1,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @Id;

    WAITFOR DELAY '00:00:02';

    COMMIT TRAN;
END
GO

/* ============================================================
   5. DEMO OBJECTS - DEADLOCK (SPRINT 4/5)
   ============================================================ */

IF OBJECT_ID(N'dbo.DeadlockDemoA', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DeadlockDemoA
    (
        Id           int           NOT NULL CONSTRAINT PK_DeadlockDemoA PRIMARY KEY,
        CounterValue int           NOT NULL,
        UpdatedAt    datetime2(3)  NOT NULL
    );

    INSERT INTO dbo.DeadlockDemoA(Id, CounterValue, UpdatedAt)
    VALUES (1, 0, SYSUTCDATETIME());
END
GO

IF OBJECT_ID(N'dbo.DeadlockDemoB', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DeadlockDemoB
    (
        Id           int           NOT NULL CONSTRAINT PK_DeadlockDemoB PRIMARY KEY,
        CounterValue int           NOT NULL,
        UpdatedAt    datetime2(3)  NOT NULL
    );

    INSERT INTO dbo.DeadlockDemoB(Id, CounterValue, UpdatedAt)
    VALUES (1, 0, SYSUTCDATETIME());
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_DeadlockDemo_A
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET DEADLOCK_PRIORITY NORMAL;

    BEGIN TRAN;

    UPDATE dbo.DeadlockDemoA
    SET CounterValue = CounterValue + 1,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = 1;

    WAITFOR DELAY '00:00:01';

    UPDATE dbo.DeadlockDemoB
    SET CounterValue = CounterValue + 1,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = 1;

    COMMIT TRAN;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_DeadlockDemo_B
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET DEADLOCK_PRIORITY NORMAL;

    BEGIN TRAN;

    UPDATE dbo.DeadlockDemoB
    SET CounterValue = CounterValue + 1,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = 1;

    WAITFOR DELAY '00:00:01';

    UPDATE dbo.DeadlockDemoA
    SET CounterValue = CounterValue + 1,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = 1;

    COMMIT TRAN;
END
GO

/* ============================================================
   6. HELPER VIEWS - SPRINT 5/6
   ============================================================ */

CREATE OR ALTER VIEW dbo.v_StressRunLatest
AS
SELECT
    sr.RunId,
    sr.ProfileName,
    sr.ScenarioName,
    sr.EnvironmentName,
    sr.ServerName,
    sr.DatabaseName,
    sr.TotalExecutions,
    sr.SuccessCount,
    sr.ErrorCount,
    sr.RetryCount,
    sr.AvgDurationMs,
    sr.P95DurationMs,
    sr.ThroughputPerSecond,
    sr.StartedAtUtc,
    sr.FinishedAtUtc
FROM dbo.StressRun AS sr;
GO

CREATE OR ALTER VIEW dbo.v_StressRunTrend
AS
SELECT
    sr.ProfileName,
    sr.RunId,
    sr.StartedAtUtc,
    sr.AvgDurationMs,
    sr.P95DurationMs,
    sr.ThroughputPerSecond,
    sr.ErrorCount,
    sr.RetryCount
FROM dbo.StressRun AS sr;
GO

/* ============================================================
   7. OPTIONAL SEED / VERIFY
   ============================================================ */
PRINT 'StressLabDb i obiekty Sprint 1-6 gotowe.';
GO