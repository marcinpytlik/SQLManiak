/*
 LAB ONLY. Requires 001-013; transaction rolls back synthetic data.
 Checks remote classification -> proposals -> approval -> claim -> completion.
 No remote connection, no ALTER INDEX. Do not run against production central repository.
*/
USE [SQLManiakIndexMaintenance];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 DECLARE @instanceId bigint,@dbId bigint,@runId bigint,@qId bigint,
         @token uniqueidentifier,@name nvarchar(256)=N'LAB_IM_TEST_'+CONVERT(nvarchar(36),NEWID());
 INSERT im.ManagedInstance(InstanceName,InstanceType,IsEnabled) VALUES(@name,'STANDALONE',1);
 SET @instanceId=SCOPE_IDENTITY();
 INSERT im.ConnectionEndpoint(InstanceId,ServerAddress,IsPrimary,IsEnabled)
 VALUES(@instanceId,N'lab-only-no-connect',1,1);
 INSERT im.ManagedDatabase(InstanceId,DatabaseName,IsEnabled)
 VALUES(@instanceId,N'LAB_ONLY',1);
 SET @dbId=SCOPE_IDENTITY();
 INSERT im.AuditRun(DatabaseId,Status) VALUES(@dbId,'Running');
 SET @runId=SCOPE_IDENTITY();
 INSERT im.RemoteIndexStage
 (AuditRunId,ObjectId,IndexId,PartitionNumber,SchemaName,TableName,IndexName,
 IndexType,PageCount,FragmentationPercent,PageDensityPercent,MeasurementMode)
 VALUES
 (@runId,100,1,1,N'dbo',N'T1',N'IX_A',2,2000,45,90,'SAMPLED'),
 (@runId,101,1,1,N'dbo',N'T2',N'IX_B',2,2000,15,90,'SAMPLED'),
 (@runId,102,1,1,N'dbo',N'T3',N'IX_C',2,150000,40,90,'SAMPLED'),
 (@runId,103,1,1,N'dbo',N'T4',N'IX_D',2,2000,2,98,'SAMPLED');
 EXEC im.ClassifyRemoteAudit @RunId=@runId;
 IF (SELECT COUNT(*) FROM im.IndexAssessment WHERE AuditRunId=@runId)<>4
    THROW 51201,'Assessment row count mismatch',1;
 IF NOT EXISTS(SELECT 1 FROM im.IndexAssessment WHERE AuditRunId=@runId
 AND ObjectId=100 AND Classification='REBUILD_CANDIDATE')
    THROW 51202,'Rebuild classification mismatch',1;
 IF NOT EXISTS(SELECT 1 FROM im.IndexAssessment WHERE AuditRunId=@runId
 AND ObjectId=101 AND Classification='REORGANIZE_CANDIDATE')
    THROW 51203,'Reorganize classification mismatch',1;
 IF NOT EXISTS(SELECT 1 FROM im.IndexAssessment WHERE AuditRunId=@runId
 AND ObjectId=102 AND Classification='REVIEW')
    THROW 51204,'Large partition review mismatch',1;
 UPDATE im.AuditRun SET Status='Completed',CompletedAtUtc=SYSUTCDATETIME()
 WHERE AuditRunId=@runId;
 EXEC im.ProposeMaintenance @AuditRunId=@runId;
 IF (SELECT COUNT(*) FROM im.MaintenanceQueue q
 JOIN im.IndexAssessment a ON a.AssessmentId=q.AssessmentId
 WHERE a.AuditRunId=@runId)<>2
    THROW 51205,'Queue should contain exactly two proposals',1;
 SELECT TOP (1) @qId=q.QueueId
 FROM im.MaintenanceQueue q JOIN im.IndexAssessment a ON a.AssessmentId=q.AssessmentId
 WHERE a.AuditRunId=@runId AND a.ObjectId=100;
 EXEC im.ApproveMaintenance @QueueId=@qId,@ApprovalName=N'LAB_TEST_DBA';
 CREATE TABLE #ClaimResult(QueueId bigint,InstanceName nvarchar(256),
 ServerAddress nvarchar(256),Port int NULL,DatabaseName sysname,SchemaName sysname,
 TableName sysname,IndexName sysname,ObjectId int,IndexId int,
 PartitionNumber int,PageCount bigint,Operation varchar(12),Status varchar(16),
 ExecutionToken uniqueidentifier);
 INSERT #ClaimResult
 EXEC im.ClaimMaintenance @QueueId=@qId,@ExecutionToken=@token OUTPUT;
 IF @token IS NULL THROW 51206,'Claim token missing',1;
 IF NOT EXISTS(SELECT 1 FROM im.MaintenanceQueue WHERE QueueId=@qId AND Status='Running')
    THROW 51207,'Claim failed',1;
 EXEC im.FinishMaintenance @QueueId=@qId,@ExecutionToken=@token,
      @Status='Skipped',@Message=N'Synthetic regression test only';
 IF NOT EXISTS(SELECT 1 FROM im.MaintenanceQueue WHERE QueueId=@qId AND Status='Skipped')
    THROW 51208,'Finish failed',1;
 PRINT 'PASS: classification, plan, approval, claim, completion';
 ROLLBACK;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
