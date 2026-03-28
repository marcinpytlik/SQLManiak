USE SqlAnomalyWatcherDb;
GO

IF OBJECT_ID('dbo.TelemetrySnapshot', 'U') IS NOT NULL
    DROP TABLE dbo.TelemetrySnapshot;
GO

CREATE TABLE dbo.TelemetrySnapshot
(
    Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CaptureTime datetime2(0) NOT NULL,
    ServerName sysname NOT NULL,
    InstanceName sysname NOT NULL,

    CpuPercent decimal(5,2) NULL,
    BatchRequestsPerSec decimal(18,2) NULL,
    UserConnections int NULL,
    BlockedSessions int NULL,
    DeadlocksPerMin int NULL,
    AvgQueryDurationMs decimal(18,2) NULL,
    AvgLogicalReads decimal(18,2) NULL,
    TempdbUsedMb decimal(18,2) NULL,
    SignalWaitTimeMs decimal(18,2) NULL,
    PageLifeExpectancy int NULL,

    CreatedAt datetime2(0) NOT NULL
        CONSTRAINT DF_TelemetrySnapshot_CreatedAt DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('dbo.ModelRun', 'U') IS NOT NULL
    DROP TABLE dbo.ModelRun;
GO

CREATE TABLE dbo.ModelRun
(
    Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RunStartedAt datetime2(0) NOT NULL,
    RunFinishedAt datetime2(0) NULL,
    RowsProcessed int NOT NULL,
    ModelName nvarchar(200) NOT NULL,
    ParametersJson nvarchar(max) NULL,
    Status nvarchar(50) NOT NULL,
    Notes nvarchar(max) NULL
);
GO

IF OBJECT_ID('dbo.AnomalyScore', 'U') IS NOT NULL
    DROP TABLE dbo.AnomalyScore;
GO

CREATE TABLE dbo.AnomalyScore
(
    Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ModelRunId bigint NOT NULL,
    TelemetrySnapshotId bigint NOT NULL,
    CaptureTime datetime2(0) NOT NULL,
    AnomalyFlag bit NOT NULL,
    AnomalyScore decimal(18,8) NOT NULL,
    KnownIncident bit NULL,
    TopReason nvarchar(400) NULL,

    CONSTRAINT FK_AnomalyScore_ModelRun
        FOREIGN KEY (ModelRunId) REFERENCES dbo.ModelRun(Id),

    CONSTRAINT FK_AnomalyScore_TelemetrySnapshot
        FOREIGN KEY (TelemetrySnapshotId) REFERENCES dbo.TelemetrySnapshot(Id)
);
GO