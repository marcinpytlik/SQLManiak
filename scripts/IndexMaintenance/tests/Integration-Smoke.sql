/* Safe read-only smoke inspection after applying migrations and running collector.
 Does not change production indices or disable backup jobs. */
USE [SQLManiakIndexMaintenance];
GO
SELECT name FROM sys.tables WHERE schema_id=SCHEMA_ID(N'im') ORDER BY name;
SELECT i.InstanceId,i.InstanceName,i.InstanceType,c.ClusterName,
 e.ServerAddress,e.IsEnabled AS EndpointEnabled,i.IsEnabled AS InstanceEnabled
FROM im.ManagedInstance i
LEFT JOIN im.Cluster c ON c.ClusterId=i.ClusterId
LEFT JOIN im.ConnectionEndpoint e ON e.InstanceId=i.InstanceId
ORDER BY i.InstanceId;
SELECT TOP(25) r.AuditRunId,i.InstanceName,d.DatabaseName,r.Status,
 r.StartedAtUtc,r.CompletedAtUtc,r.ErrorMessage,
 (SELECT COUNT_BIG(*) FROM im.IndexAssessment a WHERE a.AuditRunId=r.AuditRunId) AS ClassifiedPartitions
FROM im.AuditRun r
JOIN im.ManagedDatabase d ON d.DatabaseId=r.DatabaseId
JOIN im.ManagedInstance i ON i.InstanceId=d.InstanceId
ORDER BY r.AuditRunId DESC;
SELECT ClusterKey,ExpiresAtUtc FROM im.AuditLease;
GO
