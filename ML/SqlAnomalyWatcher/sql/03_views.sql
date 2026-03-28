USE SqlAnomalyWatcherDb;
GO

CREATE OR ALTER VIEW dbo.vw_TelemetryLatest
AS
SELECT TOP (1000)
    Id,
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
FROM dbo.TelemetrySnapshot
ORDER BY CaptureTime DESC;
GO

CREATE OR ALTER VIEW dbo.vw_RecentAnomalies
AS
SELECT
    a.Id,
    a.CaptureTime,
    a.AnomalyFlag,
    a.AnomalyScore,
    a.KnownIncident,
    a.TopReason,
    t.ServerName,
    t.InstanceName,
    t.CpuPercent,
    t.BatchRequestsPerSec,
    t.BlockedSessions,
    t.DeadlocksPerMin,
    t.AvgQueryDurationMs,
    t.TempdbUsedMb
FROM dbo.AnomalyScore a
JOIN dbo.TelemetrySnapshot t
    ON a.TelemetrySnapshotId = t.Id;
GO