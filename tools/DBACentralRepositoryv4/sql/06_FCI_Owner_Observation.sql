USE [DBACentralRepositoryv4];
GO
/* FCI OBSERVATION ONLY. Does not connect to or modify Windows Cluster. */
IF OBJECT_ID(N'inventory.FciOwnerObservation',N'U') IS NULL
BEGIN
 CREATE TABLE inventory.FciOwnerObservation(
  ScanRunId bigint NOT NULL CONSTRAINT PK_v4_FciOwnerObservation PRIMARY KEY
    REFERENCES inventory.ScanRun(ScanRunId),
  InstanceId bigint NOT NULL REFERENCES inventory.Instance(InstanceId),
  PreviousOwnerHostId bigint NULL REFERENCES inventory.Host(HostId),
  CurrentOwnerHostId bigint NOT NULL REFERENCES inventory.Host(HostId),
  IsChanged bit NOT NULL,
  ObservedUtc datetime2(0) NOT NULL
    CONSTRAINT DF_v4_FciObs_Utc DEFAULT SYSUTCDATETIME()
 );
 CREATE INDEX IX_v4_FciObs_Instance ON inventory.FciOwnerObservation(InstanceId,ObservedUtc DESC,ScanRunId DESC);
END;
GO
CREATE OR ALTER PROCEDURE inventory.usp_RecordFciObservation
 @ScanRunId bigint,
 @NodesJson nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF ISJSON(@NodesJson)<>1 THROW 54200,'Invalid FCI nodes JSON.',1;
 DECLARE @Nodes TABLE(
  NodeName sysname NOT NULL PRIMARY KEY,
  NodeStatus nvarchar(60) NULL,
  IsCurrentOwner bit NOT NULL
 );
 INSERT @Nodes(NodeName,NodeStatus,IsCurrentOwner)
 SELECT LTRIM(RTRIM(NodeName)),NodeStatus,IsCurrentOwner
 FROM OPENJSON(@NodesJson) WITH(
  NodeName nvarchar(128) '$.NodeName',
  NodeStatus nvarchar(60) '$.NodeStatus',
  IsCurrentOwner bit '$.IsCurrentOwner'
 )
 WHERE NodeName IS NOT NULL AND LEN(LTRIM(RTRIM(NodeName)))>0
   AND IsCurrentOwner IS NOT NULL;
 IF (SELECT COUNT(*) FROM @Nodes)=0
   OR (SELECT COUNT(*) FROM @Nodes WHERE IsCurrentOwner=1)<>1
   THROW 54201,'FCI requires exactly one current owner and at least one node.',1;
 DECLARE @InstanceId bigint,@PriorOwnerId bigint,@OwnerId bigint,
         @InstanceName nvarchar(256),@CurrentNode sysname;
 BEGIN TRAN;
 SELECT @InstanceId=s.InstanceId,@InstanceName=i.ServerInstance
 FROM inventory.ScanRun s WITH(UPDLOCK,HOLDLOCK)
 JOIN inventory.Instance i ON i.InstanceId=s.InstanceId
 WHERE s.ScanRunId=@ScanRunId AND s.ScanStatus='RUNNING';
 IF @InstanceId IS NULL
  THROW 54202,'FCI observation requires a RUNNING scan.',1;
 IF EXISTS(SELECT 1 FROM inventory.FciOwnerObservation WHERE ScanRunId=@ScanRunId)
  THROW 54203,'FCI observation already recorded for this scan.',1;
 SELECT @CurrentNode=NodeName FROM @Nodes WHERE IsCurrentOwner=1;
 SELECT TOP(1) @PriorOwnerId=CurrentOwnerHostId
 FROM inventory.FciOwnerObservation
 WHERE InstanceId=@InstanceId ORDER BY ScanRunId DESC;
 DECLARE @NodeName sysname;
 DECLARE node_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT NodeName FROM @Nodes;
 OPEN node_cursor;
 FETCH NEXT FROM node_cursor INTO @NodeName;
 WHILE @@FETCH_STATUS=0
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM inventory.Host WITH(UPDLOCK,HOLDLOCK) WHERE HostName=@NodeName)
   INSERT inventory.Host(HostName) VALUES(@NodeName);
  DECLARE @HostId bigint;
  SELECT @HostId=HostId FROM inventory.Host WHERE HostName=@NodeName;
  IF NOT EXISTS(SELECT 1 FROM inventory.InstanceHost WHERE InstanceId=@InstanceId AND HostId=@HostId)
   INSERT inventory.InstanceHost(InstanceId,HostId,IsCurrentOwner,LastObservedUtc)
   VALUES(@InstanceId,@HostId,0,SYSUTCDATETIME());
  FETCH NEXT FROM node_cursor INTO @NodeName;
 END;
 CLOSE node_cursor;
 DEALLOCATE node_cursor;
 SELECT @OwnerId=HostId FROM inventory.Host WHERE HostName=@CurrentNode;
 UPDATE inventory.InstanceHost
 SET IsCurrentOwner=CASE WHEN HostId=@OwnerId THEN 1 ELSE 0 END,
     LastObservedUtc=CASE WHEN HostId IN
       (SELECT h.HostId FROM inventory.Host h JOIN @Nodes n ON n.NodeName=h.HostName)
       THEN SYSUTCDATETIME() ELSE LastObservedUtc END
 WHERE InstanceId=@InstanceId;
 INSERT inventory.FciOwnerObservation(ScanRunId,InstanceId,PreviousOwnerHostId,CurrentOwnerHostId,IsChanged)
 VALUES(@ScanRunId,@InstanceId,@PriorOwnerId,@OwnerId,
  CASE WHEN @PriorOwnerId IS NOT NULL AND @PriorOwnerId<>@OwnerId THEN 1 ELSE 0 END);
 COMMIT;
 SELECT @ScanRunId AS ScanRunId,@InstanceName AS ServerInstance,
   @CurrentNode AS CurrentOwner,
   CASE WHEN @PriorOwnerId IS NOT NULL AND @PriorOwnerId<>@OwnerId THEN 1 ELSE 0 END AS OwnerChanged;
END;
GO
CREATE OR ALTER VIEW report.vFciOwnerHistory
AS
SELECT o.ScanRunId,i.ServerInstance,o.ObservedUtc,
 p.HostName AS PreviousOwner,h.HostName AS CurrentOwner,o.IsChanged
FROM inventory.FciOwnerObservation o
JOIN inventory.Instance i ON i.InstanceId=o.InstanceId
JOIN inventory.Host h ON h.HostId=o.CurrentOwnerHostId
LEFT JOIN inventory.Host p ON p.HostId=o.PreviousOwnerHostId;
GO
