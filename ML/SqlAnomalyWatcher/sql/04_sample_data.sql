USE SqlAnomalyWatcherDb;
GO

INSERT INTO dbo.TelemetrySnapshot
(
    CaptureTime,
    ServerName,
    InstanceName,
    CpuPercent,
    BatchRequestsPerSec,
    UserConnections,
    BlockedSessions,
    DeadlocksPerMin,
    AvgQueryDurationMs,
    AvgLogicalReads,
    TempdbUsedMb,
    SignalWaitTimeMs,
    PageLifeExpectancy
)
VALUES
(
    SYSDATETIME(),
    @@SERVERNAME,
    @@SERVICENAME,
    25.00,
    125.00,
    47,
    0,
    0,
    18.00,
    240.00,
    512.00,
    4.00,
    1800
);
GO