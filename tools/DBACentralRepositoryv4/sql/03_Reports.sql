USE [DBACentralRepositoryv4];
GO
CREATE OR ALTER VIEW report.vPatchPlan
AS
SELECT
 o.OperationId, i.ServerInstance, i.EnvironmentCode, i.Architecture, i.ClusterName,
 g.GroupCode, w.WindowId, w.StartsUtc, w.EndsUtc, w.Status AS WindowStatus,
 o.TargetBuild, o.ChangeReference, o.Status AS OperationStatus,
 o.ApprovedBy, o.ApprovedUtc, o.PreScanRunId, o.PostScanRunId
FROM patch.PatchOperation o
JOIN inventory.Instance i ON i.InstanceId=o.InstanceId
JOIN patch.MaintenanceWindow w ON w.WindowId=o.WindowId
JOIN patch.PatchGroup g ON g.PatchGroupId=w.PatchGroupId;
GO
CREATE OR ALTER VIEW report.vLatestInventoryScans
AS
WITH ranked AS (
  SELECT s.InstanceId,s.ScanRunId,s.ScanType,s.ScanStatus,s.StartedUtc,s.FinishedUtc,
  ROW_NUMBER() OVER(PARTITION BY s.InstanceId ORDER BY s.StartedUtc DESC,s.ScanRunId DESC) AS rn
  FROM inventory.ScanRun s
)
SELECT i.ServerInstance,i.EnvironmentCode,i.Architecture,
 r.ScanRunId,r.ScanType,r.ScanStatus,r.StartedUtc,r.FinishedUtc
FROM inventory.Instance i
LEFT JOIN ranked r ON r.InstanceId=i.InstanceId AND r.rn=1;
GO
CREATE OR ALTER VIEW report.vInventoryCoverage
AS
SELECT s.ScanRunId, i.ServerInstance, s.ScanStatus, x.Category, x.EntityCount
FROM inventory.ScanRun s
JOIN inventory.Instance i ON i.InstanceId=s.InstanceId
CROSS APPLY (
 SELECT Category,COUNT_BIG(*) AS EntityCount
 FROM inventory.InventorySnapshot sn
 WHERE sn.ScanRunId=s.ScanRunId
 GROUP BY Category
) x;
GO
