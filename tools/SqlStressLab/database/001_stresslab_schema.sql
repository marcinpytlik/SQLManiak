CREATE TABLE dbo.StressRun
(
    RunId                nvarchar(50)  NOT NULL PRIMARY KEY,
    ProfileName          nvarchar(200) NOT NULL,
    ScenarioName         nvarchar(100) NOT NULL,
    ServerName           nvarchar(200) NOT NULL,
    DatabaseName         nvarchar(200) NOT NULL,
    CommandType          nvarchar(50)  NOT NULL,
    ExecutionMode        nvarchar(50)  NOT NULL,
    Workers              int           NOT NULL,
    IterationsPerWorker  int           NOT NULL,
    TotalExecutions      int           NOT NULL,
    SuccessCount         int           NOT NULL,
    ErrorCount           int           NOT NULL,
    RetryCount           int           NOT NULL,
    AvgDurationMs        float         NOT NULL,
    MinDurationMs        bigint        NOT NULL,
    P50DurationMs        bigint        NOT NULL,
    P95DurationMs        bigint        NOT NULL,
    P99DurationMs        bigint        NOT NULL,
    MaxDurationMs        bigint        NOT NULL,
    ThroughputPerSecond  float         NOT NULL,
    StartedAtUtc         datetime2(3)  NOT NULL,
    FinishedAtUtc        datetime2(3)  NOT NULL,
    WallClockMs          bigint        NOT NULL
);
GO

CREATE TABLE dbo.StressRunSample
(
    StressRunSampleId    bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RunId                nvarchar(50)  NOT NULL,
    WorkerId             int           NOT NULL,
    Iteration            int           NOT NULL,
    StartedAtUtc         datetime2(3)  NOT NULL,
    DurationMs           bigint        NOT NULL,
    Success              bit           NOT NULL,
    RetryAttempt         int           NOT NULL,
    ErrorCategory        nvarchar(100) NULL,
    SqlErrorNumber       int           NULL,
    ErrorMessage         nvarchar(max) NULL,
    ScalarValue          nvarchar(4000) NULL,
    ReaderRowCount       int           NULL
);
GO

CREATE INDEX IX_StressRunSample_RunId
ON dbo.StressRunSample(RunId);
GO
USE StressLabDb;
GO

IF OBJECT_ID('dbo.BlockingDemo', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.BlockingDemo
    (
        Id int NOT NULL CONSTRAINT PK_BlockingDemo PRIMARY KEY,
        CounterValue int NOT NULL,
        UpdatedAt datetime2(3) NOT NULL
    );

    INSERT INTO dbo.BlockingDemo (Id, CounterValue, UpdatedAt)
    VALUES (1, 0, SYSUTCDATETIME());
END
GO
USE StressLabDb;
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