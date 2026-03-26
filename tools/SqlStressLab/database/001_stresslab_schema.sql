SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================
   SqlStressLab Repository
   wersja: Sprint 10
   autor: SQLManiak
   ============================================================ */

DECLARE @DatabaseName sysname = N'SqlStressLab';
DECLARE @DataPath nvarchar(4000) = NULL; -- np. N'C:\SQLData'
DECLARE @LogPath  nvarchar(4000) = NULL; -- np. N'C:\SQLLogs'
GO

/* ============================================================
   1. Utworzenie bazy danych
   ============================================================ */
DECLARE @DatabaseName sysname = N'SqlStressLab';
DECLARE @DataPath nvarchar(4000) = NULL;
DECLARE @LogPath  nvarchar(4000) = NULL;

IF DB_ID(@DatabaseName) IS NULL
BEGIN
    DECLARE @Sql nvarchar(max) = N'CREATE DATABASE ' + QUOTENAME(@DatabaseName);

    IF @DataPath IS NOT NULL AND @LogPath IS NOT NULL
    BEGIN
        SET @Sql += N'
        ON PRIMARY
        (
            NAME = N''' + @DatabaseName + N''',
            FILENAME = N''' + @DataPath + CASE WHEN RIGHT(@DataPath,1) IN ('\','/') THEN N'' ELSE N'\' END + @DatabaseName + N'.mdf' + N''',
            SIZE = 256MB,
            FILEGROWTH = 64MB
        )
        LOG ON
        (
            NAME = N''' + @DatabaseName + N'_log'',
            FILENAME = N''' + @LogPath + CASE WHEN RIGHT(@LogPath,1) IN ('\','/') THEN N'' ELSE N'\' END + @DatabaseName + N'_log.ldf' + N''',
            SIZE = 128MB,
            FILEGROWTH = 64MB
        );';
    END
    ELSE
    BEGIN
        SET @Sql += N';';
    END

    PRINT N'Tworzę bazę ' + QUOTENAME(@DatabaseName) + N'...';
    EXEC sys.sp_executesql @Sql;
END
ELSE
BEGIN
    PRINT N'Baza ' + QUOTENAME(@DatabaseName) + N' już istnieje.';
END
GO

DECLARE @DatabaseName sysname = N'SqlStressLab';
DECLARE @Sql nvarchar(max) = N'ALTER DATABASE ' + QUOTENAME(@DatabaseName) + N' SET RECOVERY SIMPLE WITH NO_WAIT;';
EXEC sys.sp_executesql @Sql;
GO

DECLARE @DatabaseName sysname = N'SqlStressLab';
DECLARE @Sql nvarchar(max) = N'ALTER DATABASE ' + QUOTENAME(@DatabaseName) + N' SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;';
EXEC sys.sp_executesql @Sql;
GO

/* ============================================================
   2. Obiekty w bazie
   ============================================================ */
USE [SqlStressLab];
GO

/* ============================================================
   2.1 Schemat
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dbo')
BEGIN
    EXEC('CREATE SCHEMA dbo AUTHORIZATION dbo;');
END
GO

/* ============================================================
   2.2 Tabela główna runów
   ============================================================ */
IF OBJECT_ID(N'dbo.StressRun', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.StressRun
    (
        RunId                    nvarchar(64)   NOT NULL,
        ProfileName              nvarchar(200)  NOT NULL,
        ScenarioName             nvarchar(200)  NOT NULL,
        TagsCsv                  nvarchar(1000) NULL,

        EnvironmentName          nvarchar(200)  NULL,
        MachineName              nvarchar(200)  NULL,
        OsVersion                nvarchar(400)  NULL,
        DotNetVersion            nvarchar(100)  NULL,

        ServerName               nvarchar(200)  NOT NULL,
        DatabaseName             nvarchar(200)  NOT NULL,
        CommandType              nvarchar(50)   NOT NULL,
        ExecutionMode            nvarchar(50)   NOT NULL,

        Workers                  int            NOT NULL,
        IterationsPerWorker      int            NOT NULL,

        TotalExecutions          int            NOT NULL,
        SuccessCount             int            NOT NULL,
        ErrorCount               int            NOT NULL,
        RetryCount               int            NOT NULL,

        AvgDurationMs            decimal(18,2)  NOT NULL,
        MinDurationMs            bigint         NOT NULL,
        P50DurationMs            bigint         NOT NULL,
        P95DurationMs            bigint         NOT NULL,
        P99DurationMs            bigint         NOT NULL,
        MaxDurationMs            bigint         NOT NULL,
        ThroughputPerSecond      decimal(18,4)  NOT NULL,

        StartedAtUtc             datetime2(3)   NOT NULL,
        FinishedAtUtc            datetime2(3)   NOT NULL,
        WallClockMs              bigint         NOT NULL,

        SqlProductVersion        nvarchar(100)  NULL,
        SqlProductLevel          nvarchar(100)  NULL,
        SqlEdition               nvarchar(200)  NULL,
        SqlEngineEdition         nvarchar(100)  NULL,
        SqlInstanceName          nvarchar(200)  NULL,
        SqlCompatibilityLevel    int            NULL,

        CreatedAtUtc             datetime2(3)   NOT NULL
            CONSTRAINT DF_StressRun_CreatedAtUtc DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_StressRun PRIMARY KEY CLUSTERED (RunId)
    );
END
GO

/* ============================================================
   2.3 Próbki wykonania
   ============================================================ */
IF OBJECT_ID(N'dbo.StressRunSample', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.StressRunSample
    (
        StressRunSampleId        bigint         NOT NULL IDENTITY(1,1),
        RunId                    nvarchar(64)   NOT NULL,

        WorkerId                 int            NOT NULL,
        Iteration                int            NOT NULL,
        StartedAtUtc             datetime2(3)   NOT NULL,
        DurationMs               bigint         NOT NULL,
        Success                  bit            NOT NULL,
        RetryAttempt             int            NOT NULL,

        ErrorCategory            nvarchar(100)  NULL,
        SqlErrorNumber           int            NULL,
        ErrorMessage             nvarchar(4000) NULL,

        ScalarValue              nvarchar(4000) NULL,
        ReaderRowCount           int            NULL,

        Spid                     int            NULL,
        HostName                 nvarchar(200)  NULL,
        AppName                  nvarchar(200)  NULL,
        LoginName                nvarchar(200)  NULL,
        DatabaseName             nvarchar(200)  NULL,

        CreatedAtUtc             datetime2(3)   NOT NULL
            CONSTRAINT DF_StressRunSample_CreatedAtUtc DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_StressRunSample PRIMARY KEY CLUSTERED (StressRunSampleId),

        CONSTRAINT FK_StressRunSample_StressRun
            FOREIGN KEY (RunId)
            REFERENCES dbo.StressRun (RunId)
            ON DELETE CASCADE
    );
END
GO

/* ============================================================
   2.4 Snapshoty DMV - nagłówek logiczny w wierszach
   ============================================================ */
IF OBJECT_ID(N'dbo.StressRunDmvSnapshot', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.StressRunDmvSnapshot
    (
        StressRunDmvSnapshotId   bigint          NOT NULL IDENTITY(1,1),
        RunId                    nvarchar(64)    NOT NULL,
        PhaseName                nvarchar(50)    NOT NULL,   -- Before / After
        SnapshotType             nvarchar(100)   NOT NULL,   -- waits / requests / locks / sessions itp.
        CapturedAtUtc            datetime2(3)    NOT NULL,
        RowNumber                int             NOT NULL,
        PayloadJson              nvarchar(max)   NOT NULL,

        CreatedAtUtc             datetime2(3)    NOT NULL
            CONSTRAINT DF_StressRunDmvSnapshot_CreatedAtUtc DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_StressRunDmvSnapshot PRIMARY KEY CLUSTERED (StressRunDmvSnapshotId),

        CONSTRAINT FK_StressRunDmvSnapshot_StressRun
            FOREIGN KEY (RunId)
            REFERENCES dbo.StressRun (RunId)
            ON DELETE CASCADE
    );
END
GO

/* ============================================================
   2.5 Porównania runów
   ============================================================ */
IF OBJECT_ID(N'dbo.StressRunComparison', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.StressRunComparison
    (
        StressRunComparisonId    bigint         NOT NULL IDENTITY(1,1),
        RunId                    nvarchar(64)   NOT NULL,
        BaselineRunId            nvarchar(64)   NOT NULL,

        AvgDurationDeltaMs       decimal(18,2)  NOT NULL,
        P95DurationDeltaMs       bigint         NOT NULL,
        ThroughputDelta          decimal(18,4)  NOT NULL,
        ErrorCountDelta          int            NOT NULL,
        RetryCountDelta          int            NOT NULL,
        IsRegression             bit            NOT NULL,

        ComparedAtUtc            datetime2(3)   NOT NULL,

        CreatedAtUtc             datetime2(3)   NOT NULL
            CONSTRAINT DF_StressRunComparison_CreatedAtUtc DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_StressRunComparison PRIMARY KEY CLUSTERED (StressRunComparisonId),

        CONSTRAINT FK_StressRunComparison_Run
            FOREIGN KEY (RunId)
            REFERENCES dbo.StressRun (RunId)
            ON DELETE CASCADE,

        CONSTRAINT FK_StressRunComparison_BaselineRun
            FOREIGN KEY (BaselineRunId)
            REFERENCES dbo.StressRun (RunId)
            ON DELETE NO ACTION
    );
END
GO

/* ============================================================
   3. Indeksy
   ============================================================ */
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_StressRun_ProfileName_StartedAtUtc'
      AND object_id = OBJECT_ID(N'dbo.StressRun')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_StressRun_ProfileName_StartedAtUtc
    ON dbo.StressRun (ProfileName, StartedAtUtc DESC)
    INCLUDE
    (
        ScenarioName,
        AvgDurationMs,
        P95DurationMs,
        ThroughputPerSecond,
        ErrorCount,
        RetryCount
    );
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_StressRun_StartedAtUtc'
      AND object_id = OBJECT_ID(N'dbo.StressRun')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_StressRun_StartedAtUtc
    ON dbo.StressRun (StartedAtUtc DESC)
    INCLUDE (ProfileName, ScenarioName, AvgDurationMs, P95DurationMs, ThroughputPerSecond, ErrorCount);
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_StressRunSample_RunId_WorkerId_Iteration'
      AND object_id = OBJECT_ID(N'dbo.StressRunSample')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_StressRunSample_RunId_WorkerId_Iteration
    ON dbo.StressRunSample (RunId, WorkerId, Iteration);
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_StressRunSample_RunId_Success_DurationMs'
      AND object_id = OBJECT_ID(N'dbo.StressRunSample')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_StressRunSample_RunId_Success_DurationMs
    ON dbo.StressRunSample (RunId, Success, DurationMs DESC)
    INCLUDE (SqlErrorNumber, ErrorCategory, RetryAttempt);
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_StressRunDmvSnapshot_RunId_Phase_SnapshotType'
      AND object_id = OBJECT_ID(N'dbo.StressRunDmvSnapshot')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_StressRunDmvSnapshot_RunId_Phase_SnapshotType
    ON dbo.StressRunDmvSnapshot (RunId, PhaseName, SnapshotType, RowNumber);
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_StressRunComparison_RunId'
      AND object_id = OBJECT_ID(N'dbo.StressRunComparison')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_StressRunComparison_RunId
    ON dbo.StressRunComparison (RunId)
    INCLUDE (BaselineRunId, AvgDurationDeltaMs, P95DurationDeltaMs, ThroughputDelta, ErrorCountDelta, IsRegression, ComparedAtUtc);
END
GO

/* ============================================================
   4. Widoki pomocnicze
   ============================================================ */
CREATE OR ALTER VIEW dbo.v_StressRunLatestByProfile
AS
WITH Runs AS
(
    SELECT
        sr.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY sr.ProfileName
            ORDER BY sr.StartedAtUtc DESC, sr.RunId DESC
        ) AS rn
    FROM dbo.StressRun sr
)
SELECT *
FROM Runs
WHERE rn = 1;
GO

CREATE OR ALTER VIEW dbo.v_StressRunComparisonLatest
AS
WITH Cte AS
(
    SELECT
        c.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY c.RunId
            ORDER BY c.ComparedAtUtc DESC, c.StressRunComparisonId DESC
        ) AS rn
    FROM dbo.StressRunComparison c
)
SELECT *
FROM Cte
WHERE rn = 1;
GO

/* ============================================================
   5. Procedury pomocnicze
   ============================================================ */
CREATE OR ALTER PROCEDURE dbo.usp_StressRun_GetLatestRunsByProfile
    @ProfileName nvarchar(200),
    @Top int = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @Top IS NULL OR @Top <= 0
        SET @Top = 10;

    SELECT TOP (@Top)
        sr.RunId,
        sr.ProfileName,
        sr.ScenarioName,
        sr.ServerName,
        sr.DatabaseName,
        sr.Workers,
        sr.IterationsPerWorker,
        sr.TotalExecutions,
        sr.SuccessCount,
        sr.ErrorCount,
        sr.RetryCount,
        sr.AvgDurationMs,
        sr.P95DurationMs,
        sr.P99DurationMs,
        sr.ThroughputPerSecond,
        sr.StartedAtUtc,
        sr.FinishedAtUtc
    FROM dbo.StressRun sr
    WHERE sr.ProfileName = @ProfileName
    ORDER BY sr.StartedAtUtc DESC, sr.RunId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_StressRun_GetRunById
    @RunId nvarchar(64)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        sr.*
    FROM dbo.StressRun sr
    WHERE sr.RunId = @RunId;
END
GO

/* ============================================================
   6. Uprawnienia - opcjonalne role
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'SqlStressLabWriter')
BEGIN
    CREATE ROLE SqlStressLabWriter AUTHORIZATION dbo;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'SqlStressLabReader')
BEGIN
    CREATE ROLE SqlStressLabReader AUTHORIZATION dbo;
END
GO

GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.StressRun TO SqlStressLabWriter;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.StressRunSample TO SqlStressLabWriter;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.StressRunDmvSnapshot TO SqlStressLabWriter;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.StressRunComparison TO SqlStressLabWriter;
GRANT EXECUTE ON dbo.usp_StressRun_GetLatestRunsByProfile TO SqlStressLabWriter;
GRANT EXECUTE ON dbo.usp_StressRun_GetRunById TO SqlStressLabWriter;
GO

GRANT SELECT ON dbo.StressRun TO SqlStressLabReader;
GRANT SELECT ON dbo.StressRunSample TO SqlStressLabReader;
GRANT SELECT ON dbo.StressRunDmvSnapshot TO SqlStressLabReader;
GRANT SELECT ON dbo.StressRunComparison TO SqlStressLabReader;
GRANT SELECT ON dbo.v_StressRunLatestByProfile TO SqlStressLabReader;
GRANT SELECT ON dbo.v_StressRunComparisonLatest TO SqlStressLabReader;
GRANT EXECUTE ON dbo.usp_StressRun_GetLatestRunsByProfile TO SqlStressLabReader;
GRANT EXECUTE ON dbo.usp_StressRun_GetRunById TO SqlStressLabReader;
GO

/* ============================================================
   7. Informacja końcowa
   ============================================================ */
PRINT N'Gotowe. Repozytorium SqlStressLab zostało przygotowane.';
PRINT N'Baza: SqlStressLab';
GO