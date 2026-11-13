USE [SQLManiakIndexMaintenance];
GO
IF OBJECT_ID(N'im.AuditLease',N'U') IS NULL
CREATE TABLE im.AuditLease(
 ClusterKey nvarchar(256) NOT NULL PRIMARY KEY,
 OwnerToken uniqueidentifier NOT NULL,
 ExpiresAtUtc datetime2(3) NOT NULL
);
GO
IF OBJECT_ID(N'im.RemoteIndexStage',N'U') IS NULL
CREATE TABLE im.RemoteIndexStage(
 AuditRunId bigint NOT NULL,
 ObjectId int NOT NULL,IndexId int NOT NULL,PartitionNumber int NOT NULL,
 SchemaName sysname NOT NULL,TableName sysname NOT NULL,IndexName sysname NOT NULL,
 IndexType tinyint NOT NULL,PageCount bigint NOT NULL,
 FragmentationPercent float NULL,PageDensityPercent float NULL,
 MeasurementMode varchar(10) NOT NULL,
 CONSTRAINT PK_RemoteIndexStage PRIMARY KEY(AuditRunId,ObjectId,IndexId,PartitionNumber),
 CONSTRAINT FK_RemoteIndexStage_Run FOREIGN KEY(AuditRunId) REFERENCES im.AuditRun(AuditRunId)
);
GO
CREATE OR ALTER PROCEDURE im.BeginRemoteAudit
 @InstanceId bigint,@DatabaseName sysname,@LeaseMinutes int=120,
 @RunId bigint OUTPUT,@Token uniqueidentifier OUTPUT
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @LeaseMinutes NOT BETWEEN 1 AND 1440 RETURN;
 DECLARE @clusterKey nvarchar(256),@dbId bigint;
 SET @Token=NEWID();
 BEGIN TRAN;
 SELECT @clusterKey=COALESCE(CONVERT(nvarchar(256),i.ClusterId),N'INSTANCE:'+CONVERT(nvarchar(30),i.InstanceId))
 FROM im.ManagedInstance i WITH(UPDLOCK,HOLDLOCK)
 WHERE i.InstanceId=@InstanceId AND i.IsEnabled=1;
 IF @clusterKey IS NULL THROW 51020,'Instance is not enabled',1;
 SELECT @dbId=d.DatabaseId FROM im.ManagedDatabase d
 WHERE d.InstanceId=@InstanceId AND d.DatabaseName=@DatabaseName AND d.IsEnabled=1;
 IF @dbId IS NULL THROW 51021,'Database is not enabled',1;
 IF EXISTS(SELECT 1 FROM im.AuditLease WITH(UPDLOCK,HOLDLOCK)
           WHERE ClusterKey=@clusterKey AND ExpiresAtUtc>SYSUTCDATETIME())
 THROW 51022,'Cluster audit lease is busy',1;
 DELETE FROM im.AuditLease WHERE ClusterKey=@clusterKey;
 INSERT im.AuditLease(ClusterKey,OwnerToken,ExpiresAtUtc)
 VALUES(@clusterKey,@Token,DATEADD(minute,@LeaseMinutes,SYSUTCDATETIME()));
 INSERT im.AuditRun(DatabaseId,Status) VALUES(@dbId,'Running');
 SET @RunId=SCOPE_IDENTITY();
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE im.CompleteRemoteAudit
 @RunId bigint,@Token uniqueidentifier,@Status varchar(16)= 'Completed',
 @ErrorMessage nvarchar(4000)=NULL
AS
BEGIN
 SET XACT_ABORT ON;SET NOCOUNT ON;
 IF @Status NOT IN ('Completed','Failed','Cancelled') THROW 51023,'Invalid completion status',1;
 DECLARE @key nvarchar(256);
 BEGIN TRAN;
 SELECT @key=COALESCE(CONVERT(nvarchar(256),i.ClusterId),N'INSTANCE:'+CONVERT(nvarchar(30),i.InstanceId))
 FROM im.AuditRun r
 JOIN im.ManagedDatabase d ON d.DatabaseId=r.DatabaseId
 JOIN im.ManagedInstance i ON i.InstanceId=d.InstanceId
 WHERE r.AuditRunId=@RunId AND r.Status='Running';
 IF @key IS NULL THROW 51024,'Run is not active',1;
 IF NOT EXISTS(SELECT 1 FROM im.AuditLease WITH(UPDLOCK,HOLDLOCK)
 WHERE ClusterKey=@key AND OwnerToken=@Token)
 THROW 51025,'Lease owner mismatch',1;
 UPDATE im.AuditRun SET Status=@Status,CompletedAtUtc=SYSUTCDATETIME(),ErrorMessage=@ErrorMessage
 WHERE AuditRunId=@RunId;
 DELETE FROM im.AuditLease WHERE ClusterKey=@key AND OwnerToken=@Token;
 COMMIT;
END;
GO
