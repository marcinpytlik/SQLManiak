USE SqlAnomalyWatcherDb;
GO

CREATE INDEX IX_TelemetrySnapshot_CaptureTime
    ON dbo.TelemetrySnapshot(CaptureTime);
GO

CREATE INDEX IX_TelemetrySnapshot_Server_Instance_CaptureTime
    ON dbo.TelemetrySnapshot(ServerName, InstanceName, CaptureTime);
GO

CREATE INDEX IX_AnomalyScore_CaptureTime
    ON dbo.AnomalyScore(CaptureTime);
GO

CREATE INDEX IX_AnomalyScore_AnomalyFlag_CaptureTime
    ON dbo.AnomalyScore(AnomalyFlag, CaptureTime);
GO