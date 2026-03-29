USE SqlAnomalyWatcherDb;
GO

CREATE OR ALTER VIEW dbo.vw_AnomalyReport
AS
SELECT
    a.Id AS AnomalyScoreId,
    a.ModelRunId,
    a.TelemetrySnapshotId,
    a.CaptureTime,
    a.AnomalyFlag,
    a.AnomalyScore,
    a.TopReason1,
    a.TopReason2,
    a.TopReason3,

    t.ServerName,
    t.InstanceName,
    t.CpuPercent,
    t.BatchRequestsPerSec,
    t.UserConnections,
    t.BlockedSessions,
    t.DeadlocksPerMin,
    t.AvgQueryDurationMs,
    t.AvgLogicalReads,
    t.TempdbUsedMb,
    t.SignalWaitTimeMs,
    t.PageLifeExpectancy
FROM dbo.AnomalyScore a
JOIN dbo.TelemetrySnapshot t
    ON a.TelemetrySnapshotId = t.Id;
GO
select * from dbo.vw_AnomalyReport