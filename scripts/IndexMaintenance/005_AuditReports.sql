/*
 SQLManiak Index Maintenance — reports.
 Run after 001-004 and at least one EXEC im.RunIndexAudit.
*/
USE [SQLManiakIndexMaintenance];
GO
-- Recent runs across managed databases
SELECT TOP (50) i.InstanceName,d.DatabaseName,r.AuditRunId,r.Status,
       r.StartedAtUtc,r.CompletedAtUtc,r.ErrorMessage
FROM im.AuditRun AS r
JOIN im.ManagedDatabase AS d ON d.DatabaseId=r.DatabaseId
JOIN im.ManagedInstance AS i ON i.InstanceId=d.InstanceId
ORDER BY r.AuditRunId DESC;
GO
-- Classification summary for the most recent completed audit in each database
WITH Latest AS
(
 SELECT r.*,ROW_NUMBER() OVER
  (PARTITION BY r.DatabaseId ORDER BY r.AuditRunId DESC) AS rn
 FROM im.AuditRun AS r WHERE r.Status='Completed'
)
SELECT i.InstanceName,d.DatabaseName,a.Classification,a.Priority,
       COUNT_BIG(*) AS Partitions, SUM(a.PageCount) AS Pages
FROM Latest AS r
JOIN im.ManagedDatabase AS d ON d.DatabaseId=r.DatabaseId
JOIN im.ManagedInstance AS i ON i.InstanceId=d.InstanceId
JOIN im.IndexAssessment AS a ON a.AuditRunId=r.AuditRunId
WHERE r.rn=1
GROUP BY i.InstanceName,d.DatabaseName,a.Classification,a.Priority
ORDER BY i.InstanceName,d.DatabaseName,a.Priority,a.Classification;
GO
-- Most significant candidates for review (latest completed audit per database)
WITH Latest AS
(
 SELECT r.AuditRunId,r.DatabaseId,ROW_NUMBER() OVER
 (PARTITION BY r.DatabaseId ORDER BY r.AuditRunId DESC) AS rn
 FROM im.AuditRun AS r WHERE r.Status='Completed'
)
SELECT TOP (100) d.DatabaseName,a.SchemaName,a.TableName,a.IndexName,
       a.PartitionNumber,a.PageCount,a.FragmentationPercent,
       a.PageDensityPercent,a.MeasurementMode,a.Classification,a.Priority,a.Reason
FROM Latest AS r
JOIN im.ManagedDatabase AS d ON d.DatabaseId=r.DatabaseId
JOIN im.IndexAssessment AS a ON a.AuditRunId=r.AuditRunId
WHERE r.rn=1 AND a.Classification <> 'NO_ACTION'
ORDER BY a.Priority,a.PageCount DESC;
GO
