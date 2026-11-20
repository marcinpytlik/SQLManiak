/*
 Explicitly-approved queue execution. No scheduler and no ALTER INDEX here.
 Serialized claim prevents two jobs of the same cluster running at once.
*/
USE [SQLManiakIndexMaintenance];
GO
IF COL_LENGTH(N'im.MaintenanceQueue',N'ExecutionToken') IS NULL
 ALTER TABLE im.MaintenanceQueue ADD ExecutionToken uniqueidentifier NULL;
GO
CREATE OR ALTER PROCEDURE im.ClaimMaintenance
 @QueueId bigint,@ExecutionToken uniqueidentifier OUTPUT
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 SET @ExecutionToken=NEWID();
 DECLARE @rc int,@clusterId bigint,@instanceId bigint;
 BEGIN TRAN;
 EXEC @rc=sys.sp_getapplock @Resource=N'im:maintenance-claim',
       @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=5000;
 IF @rc<0 THROW 51110,'Cannot acquire maintenance claim lock',1;
 SELECT @clusterId=i.ClusterId,@instanceId=i.InstanceId
 FROM im.MaintenanceQueue q WITH(UPDLOCK,HOLDLOCK)
 JOIN im.ManagedDatabase d ON d.DatabaseId=q.DatabaseId
 JOIN im.ManagedInstance i ON i.InstanceId=d.InstanceId
 JOIN im.ConnectionEndpoint e ON e.InstanceId=i.InstanceId AND e.IsPrimary=1 AND e.IsEnabled=1
 WHERE q.QueueId=@QueueId AND q.Status='Approved'
   AND q.ApprovedAtUtc IS NOT NULL AND i.IsEnabled=1 AND d.IsEnabled=1;
 IF @instanceId IS NULL THROW 51111,'Queue item is not approved or target is disabled',1;
 IF EXISTS
 (
  SELECT 1 FROM im.MaintenanceQueue x
  JOIN im.ManagedDatabase xd ON xd.DatabaseId=x.DatabaseId
  JOIN im.ManagedInstance xi ON xi.InstanceId=xd.InstanceId
  WHERE x.Status='Running' AND x.QueueId<>@QueueId
  AND (
   (@clusterId IS NOT NULL AND xi.ClusterId=@clusterId)
   OR (@clusterId IS NULL AND xi.InstanceId=@instanceId)
  )
 ) THROW 51112,'Maintenance already running in same cluster or instance',1;
 UPDATE im.MaintenanceQueue SET Status='Running',StartedAtUtc=SYSUTCDATETIME(),
 ExecutionMessage=N'Claimed; awaiting target validation',ExecutionToken=@ExecutionToken
 WHERE QueueId=@QueueId AND Status='Approved';
 IF @@ROWCOUNT<>1 THROW 51113,'Queue item changed during claim',1;
 COMMIT;
 SELECT q.QueueId,i.InstanceName,e.ServerAddress,e.Port,d.DatabaseName,
 q.SchemaName,q.TableName,q.IndexName,q.ObjectId,q.IndexId,q.PartitionNumber,
 q.PageCount,q.Operation,q.Status,@ExecutionToken AS ExecutionToken
 FROM im.MaintenanceQueue q
 JOIN im.ManagedDatabase d ON d.DatabaseId=q.DatabaseId
 JOIN im.ManagedInstance i ON i.InstanceId=d.InstanceId
 JOIN im.ConnectionEndpoint e ON e.InstanceId=i.InstanceId AND e.IsPrimary=1 AND e.IsEnabled=1
 WHERE q.QueueId=@QueueId;
END;
GO
CREATE OR ALTER PROCEDURE im.FinishMaintenance
 @QueueId bigint,@ExecutionToken uniqueidentifier,@Status varchar(16),@Message nvarchar(4000)=NULL
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @Status NOT IN ('Completed','Failed','Skipped') THROW 51114,'Invalid terminal status',1;
 UPDATE im.MaintenanceQueue
 SET Status=@Status,FinishedAtUtc=SYSUTCDATETIME(),ExecutionMessage=@Message
 WHERE QueueId=@QueueId AND Status='Running' AND ExecutionToken=@ExecutionToken;
 IF @@ROWCOUNT<>1 THROW 51115,'Queue item not running or already finished',1;
END;
GO
/* Manual recovery only: a crashed executor leaves the item Running; never
 automatically retry a potentially partially completed index operation. */
