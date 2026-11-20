/*
 Maintenance queue: proposal only. No SQL in this script alters target indexes.
 Runs are on remote instances; manual approval is mandatory.
*/
USE [SQLManiakIndexMaintenance];
GO
IF OBJECT_ID(N'im.MaintenanceQueue',N'U') IS NULL
BEGIN
 CREATE TABLE im.MaintenanceQueue
 (
  QueueId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_im_MaintenanceQueue PRIMARY KEY,
  AssessmentId bigint NOT NULL CONSTRAINT FK_im_Queue_Assessment REFERENCES im.IndexAssessment(AssessmentId),
  DatabaseId bigint NOT NULL CONSTRAINT FK_im_Queue_Database REFERENCES im.ManagedDatabase(DatabaseId),
  ObjectId int NOT NULL,IndexId int NOT NULL,PartitionNumber int NOT NULL,
  SchemaName sysname NOT NULL,TableName sysname NOT NULL,IndexName sysname NOT NULL,
  PageCount bigint NOT NULL,
  Operation varchar(12) NOT NULL,
  Status varchar(16) NOT NULL CONSTRAINT DF_im_Queue_Status DEFAULT('Proposed'),
  RequestedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_im_Queue_Created DEFAULT(SYSUTCDATETIME()),
  ApprovedBy sysname NULL,ApprovedAtUtc datetime2(3) NULL,
  StartedAtUtc datetime2(3) NULL,FinishedAtUtc datetime2(3) NULL,
  ExecutionMessage nvarchar(4000) NULL,
  CONSTRAINT UQ_im_Queue_Assessment UNIQUE(AssessmentId),
  CONSTRAINT CK_im_Queue_Operation CHECK(Operation IN ('REBUILD','REORGANIZE')),
  CONSTRAINT CK_im_Queue_Status CHECK(Status IN ('Proposed','Approved','Running','Completed','Failed','Cancelled','Skipped'))
 );
 CREATE INDEX IX_im_Queue_Status ON im.MaintenanceQueue(Status,DatabaseId,QueueId);
END;
GO
CREATE OR ALTER PROCEDURE im.ProposeMaintenance @AuditRunId bigint
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM im.AuditRun WHERE AuditRunId=@AuditRunId AND Status='Completed')
 THROW 51100,'Only completed audits may be planned',1;
 INSERT im.MaintenanceQueue
 (AssessmentId,DatabaseId,ObjectId,IndexId,PartitionNumber,SchemaName,TableName,
  IndexName,PageCount,Operation)
 SELECT a.AssessmentId,r.DatabaseId,a.ObjectId,a.IndexId,a.PartitionNumber,
  a.SchemaName,a.TableName,a.IndexName,a.PageCount,
  CASE WHEN a.Classification='REBUILD_CANDIDATE' THEN 'REBUILD' ELSE 'REORGANIZE' END
 FROM im.IndexAssessment a
 JOIN im.AuditRun r ON r.AuditRunId=a.AuditRunId
 WHERE a.AuditRunId=@AuditRunId
   AND a.Classification IN ('REBUILD_CANDIDATE','REORGANIZE_CANDIDATE')
   AND a.PageCount>=1000
   AND NOT EXISTS(SELECT 1 FROM im.MaintenanceQueue q WHERE q.AssessmentId=a.AssessmentId)
   AND NOT EXISTS
   (
     SELECT 1 FROM im.MaintenanceQueue q
     WHERE q.DatabaseId=r.DatabaseId AND q.ObjectId=a.ObjectId
     AND q.IndexId=a.IndexId AND q.PartitionNumber=a.PartitionNumber
     AND q.Status IN ('Proposed','Approved','Running')
   );
 SELECT @@ROWCOUNT AS AddedProposals;
END;
GO
CREATE OR ALTER PROCEDURE im.ApproveMaintenance
 @QueueId bigint,@ApprovalName sysname
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@ApprovalName)),N'') IS NULL
 THROW 51101,'Approval identity required',1;
 UPDATE im.MaintenanceQueue
 SET Status='Approved',ApprovedBy=@ApprovalName,ApprovedAtUtc=SYSUTCDATETIME()
 WHERE QueueId=@QueueId AND Status='Proposed';
 IF @@ROWCOUNT<>1 THROW 51102,'Queue item does not exist or cannot be approved',1;
END;
GO
CREATE OR ALTER VIEW im.PendingMaintenance
AS
 SELECT q.QueueId,i.InstanceName,e.ServerAddress,e.Port,d.DatabaseName,
 q.SchemaName,q.TableName,q.IndexName,q.ObjectId,q.IndexId,q.PartitionNumber,
 q.PageCount,q.Operation,q.Status,q.ApprovedBy,q.ApprovedAtUtc
 FROM im.MaintenanceQueue q
 JOIN im.ManagedDatabase d ON d.DatabaseId=q.DatabaseId
 JOIN im.ManagedInstance i ON i.InstanceId=d.InstanceId
 LEFT JOIN im.ConnectionEndpoint e ON e.InstanceId=i.InstanceId AND e.IsPrimary=1 AND e.IsEnabled=1
 WHERE q.Status IN ('Proposed','Approved');
GO
