USE [SQLManiakIndexMaintenance];
GO
/* Registration is explicit: newly created targets remain disabled until reviewed. */
CREATE OR ALTER PROCEDURE im.RegisterTarget
 @InstanceName nvarchar(256),@ServerAddress nvarchar(256),@ClusterName nvarchar(256)=NULL,
 @InstanceType varchar(16)='FCI',@Port int=NULL
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @InstanceType NOT IN ('FCI','STANDALONE','AG_REPLICA') THROW 51040,'Unsupported instance type',1;
 IF @ClusterName IS NULL AND @InstanceType='FCI' THROW 51041,'FCI requires ClusterName',1;
 DECLARE @clusterId bigint=NULL,@id bigint;
 BEGIN TRAN;
 IF @ClusterName IS NOT NULL
 BEGIN
 SELECT @clusterId=ClusterId FROM im.Cluster WITH(UPDLOCK,HOLDLOCK) WHERE ClusterName=@ClusterName;
 IF @clusterId IS NULL BEGIN
 INSERT im.Cluster(ClusterName) VALUES(@ClusterName); SET @clusterId=SCOPE_IDENTITY(); END;
 END;
 SELECT @id=InstanceId FROM im.ManagedInstance WITH(UPDLOCK,HOLDLOCK)
 WHERE InstanceName=@InstanceName;
 IF @id IS NULL BEGIN
 INSERT im.ManagedInstance(InstanceName,ClusterId,InstanceType) VALUES(@InstanceName,@clusterId,@InstanceType);
 SET @id=SCOPE_IDENTITY();
 END
 ELSE IF EXISTS(SELECT 1 FROM im.ManagedInstance WHERE InstanceId=@id AND
  (ISNULL(ClusterId,-1)<>ISNULL(@clusterId,-1) OR InstanceType<>@InstanceType))
 THROW 51042,'Existing instance topology differs; review manually',1;
 IF NOT EXISTS(SELECT 1 FROM im.ConnectionEndpoint WHERE InstanceId=@id)
 INSERT im.ConnectionEndpoint(InstanceId,ServerAddress,Port,IsPrimary,IsEnabled)
 VALUES(@id,@ServerAddress,@Port,1,0);
 COMMIT;
 SELECT @id AS InstanceId,@clusterId AS ClusterId;
END;
GO
