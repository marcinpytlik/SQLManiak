USE SqlAnomalyWatcherDb;
GO
SELECT COUNT(*) AS SnapshotCount
FROM dbo.TelemetrySnapshot;
python -m src.collector.collector
Zapisano snapshot:
CaptureTime: 2026-03-28 23:26:15.252760
ServerName: deweloper
InstanceName: MSSQLSERVER
CpuPercent: 0.00
BatchRequestsPerSec: 12726
UserConnections: 12
BlockedSessions: 0
DeadlocksPerMin: 0
AvgQueryDurationMs: 68.59721568
AvgLogicalReads: 6607.882352
TempdbUsedMb: 8.0000000
SignalWaitTimeMs: 183728374
PageLifeExpectancy: 822