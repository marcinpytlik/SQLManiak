USE SqlAnomalyWatcherDb;
GO
SELECT COUNT(*) AS SnapshotCount
FROM dbo.TelemetrySnapshot;

USE SqlAnomalyWatcherDb;
GO

SELECT TOP (20)
    Id,
    CaptureTime,
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
FROM dbo.TelemetrySnapshot
ORDER BY Id DESC;
GO