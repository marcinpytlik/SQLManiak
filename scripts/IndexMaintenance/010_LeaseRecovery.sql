/* SQLManiak: reconcile stale audits after agent crash/failover.
 Expired leases are reclaimed; incomplete audit is marked Failed for explicit retry. */
USE [SQLManiakIndexMaintenance];
GO
CREATE OR ALTER PROCEDURE im.RecoverExpiredAudits
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRAN;
 CREATE TABLE #Expired(ClusterKey nvarchar(256) NOT NULL PRIMARY KEY);
 INSERT #Expired(ClusterKey)
 SELECT ClusterKey FROM im.AuditLease WITH(UPDLOCK,HOLDLOCK)
 WHERE ExpiresAtUtc<=SYSUTCDATETIME();

 UPDATE r SET Status='Failed',CompletedAtUtc=SYSUTCDATETIME(),
 ErrorMessage=COALESCE(r.ErrorMessage,N'Lease expired after controller outage/failover; reschedule audit')
 FROM im.AuditRun r
 JOIN im.ManagedDatabase d ON d.DatabaseId=r.DatabaseId
 JOIN im.ManagedInstance i ON i.InstanceId=d.InstanceId
 JOIN #Expired x ON x.ClusterKey=COALESCE(CONVERT(nvarchar(256),i.ClusterId),
                              N'INSTANCE:'+CONVERT(nvarchar(30),i.InstanceId))
 WHERE r.Status='Running';

 DELETE l FROM im.AuditLease l JOIN #Expired x ON x.ClusterKey=l.ClusterKey;
 COMMIT;
END;
GO
