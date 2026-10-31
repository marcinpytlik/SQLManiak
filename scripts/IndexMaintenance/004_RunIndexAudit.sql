/*
 SQLManiak Index Maintenance — READ-ONLY audit and classification.
 SQL Server 2022+, local databases on the repository instance.
 LIMITED scans candidate indexes/partitions; SAMPLED only for top large partitions.
 Never runs ALTER INDEX or changes backup jobs.
*/
USE [SQLManiakIndexMaintenance];
GO
CREATE OR ALTER PROCEDURE im.RunIndexAudit
 @DatabaseName sysname,
 @MinPagesForReview int = 1000,
 @MinPagesForSample int = 10000,
 @MaxSampledPartitions int = 20
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT OFF;
 IF @DatabaseName IS NULL OR DB_ID(@DatabaseName) IS NULL
    THROW 51001, 'Database not found on this SQL Server instance.', 1;
 IF @DatabaseName IN (N'master',N'model',N'msdb',N'tempdb',N'SQLManiakIndexMaintenance')
    THROW 51002, 'System and repository databases are excluded.', 1;
 IF EXISTS (SELECT 1 FROM sys.databases WHERE name=@DatabaseName AND state_desc <> 'ONLINE')
    THROW 51003, 'Target database is not ONLINE.', 1;
 IF @MinPagesForReview < 1 OR @MinPagesForSample < @MinPagesForReview
    OR @MaxSampledPartitions < 0 OR @MaxSampledPartitions > 1000
    THROW 51004, 'Invalid audit parameters.', 1;

 DECLARE @instanceId bigint,@databaseId bigint,@auditRunId bigint;
 DECLARE @instanceName nvarchar(256)=CONVERT(nvarchar(256),SERVERPROPERTY('ServerName'));
 DECLARE @sql nvarchar(max);

 BEGIN TRY
  BEGIN TRAN;
  SELECT @instanceId=InstanceId FROM im.ManagedInstance WITH (UPDLOCK,HOLDLOCK)
    WHERE InstanceName=@instanceName;
  IF @instanceId IS NULL
  BEGIN
   INSERT im.ManagedInstance(InstanceName) VALUES(@instanceName);
   SET @instanceId=SCOPE_IDENTITY();
  END;
  SELECT @databaseId=DatabaseId FROM im.ManagedDatabase WITH (UPDLOCK,HOLDLOCK)
   WHERE InstanceId=@instanceId AND DatabaseName=@DatabaseName;
  IF @databaseId IS NULL
  BEGIN
   INSERT im.ManagedDatabase(InstanceId,DatabaseName) VALUES(@instanceId,@DatabaseName);
   SET @databaseId=SCOPE_IDENTITY();
  END;
  INSERT im.AuditRun(DatabaseId,Status) VALUES(@databaseId,'Running');
  SET @auditRunId=SCOPE_IDENTITY();
  COMMIT;

  CREATE TABLE #AuditStage
  (
   ObjectId int NOT NULL,IndexId int NOT NULL,PartitionNumber int NOT NULL,
   SchemaName sysname NOT NULL,TableName sysname NOT NULL,IndexName sysname NOT NULL,
   IndexType tinyint NOT NULL,PageCount bigint NOT NULL,
   FragmentationPercent float NULL,PageDensityPercent float NULL,
   MeasurementMode varchar(10) NOT NULL,
   CONSTRAINT PK_AuditStage PRIMARY KEY(ObjectId,IndexId,PartitionNumber)
  );

  SET @sql=N'USE '+QUOTENAME(@DatabaseName)+N';
   INSERT #AuditStage(ObjectId,IndexId,PartitionNumber,SchemaName,TableName,IndexName,
       IndexType,PageCount,FragmentationPercent,PageDensityPercent,MeasurementMode)
   SELECT i.object_id,i.index_id,ps.partition_number,s.name,o.name,i.name,
       i.type,ps.page_count,ps.avg_fragmentation_in_percent,
       ps.avg_page_space_used_in_percent,''LIMITED''
   FROM sys.indexes AS i
   JOIN sys.objects AS o ON o.object_id=i.object_id AND o.type=''U''
   JOIN sys.schemas AS s ON s.schema_id=o.schema_id
   CROSS APPLY sys.dm_db_index_physical_stats(DB_ID(),i.object_id,i.index_id,NULL,''LIMITED'') AS ps
   WHERE i.index_id > 0 AND i.type IN (1,2) AND i.is_disabled=0 AND i.is_hypothetical=0
     AND ps.index_level=0 AND ps.alloc_unit_type_desc=''IN_ROW_DATA''
     AND ps.page_count >= @minPages
     AND ps.index_id=i.index_id;';
  EXEC sys.sp_executesql @sql,N'@minPages int',@minPages=@MinPagesForReview;

  CREATE TABLE #SampleTargets(ObjectId int NOT NULL,IndexId int NOT NULL,PartitionNumber int NOT NULL,
    CONSTRAINT PK_SampleTargets PRIMARY KEY(ObjectId,IndexId,PartitionNumber));

  INSERT #SampleTargets(ObjectId,IndexId,PartitionNumber)
  SELECT TOP (@MaxSampledPartitions) ObjectId,IndexId,PartitionNumber
  FROM #AuditStage WHERE PageCount >= @MinPagesForSample
  ORDER BY PageCount DESC,ObjectId,IndexId,PartitionNumber;

  SET @sql=N'USE '+QUOTENAME(@DatabaseName)+N';
   UPDATE a
      SET a.FragmentationPercent=ps.avg_fragmentation_in_percent,
          a.PageDensityPercent=ps.avg_page_space_used_in_percent,
          a.MeasurementMode=''SAMPLED''
   FROM #AuditStage AS a
   JOIN #SampleTargets AS t ON t.ObjectId=a.ObjectId AND t.IndexId=a.IndexId
       AND t.PartitionNumber=a.PartitionNumber
   CROSS APPLY sys.dm_db_index_physical_stats(DB_ID(),t.ObjectId,t.IndexId,
       t.PartitionNumber,''SAMPLED'') AS ps
   WHERE ps.index_level=0 AND ps.alloc_unit_type_desc=''IN_ROW_DATA''
      AND ps.index_id=t.IndexId AND ps.partition_number=t.PartitionNumber;';
  IF @MaxSampledPartitions > 0 EXEC sys.sp_executesql @sql;

  INSERT im.IndexAssessment
    (AuditRunId,ObjectId,IndexId,PartitionNumber,SchemaName,TableName,IndexName,
     IndexType,PageCount,FragmentationPercent,PageDensityPercent,MeasurementMode,
     Classification,Priority,Reason)
  SELECT @auditRunId,ObjectId,IndexId,PartitionNumber,SchemaName,TableName,IndexName,
     IndexType,PageCount,FragmentationPercent,PageDensityPercent,MeasurementMode,
     CASE
       WHEN FragmentationPercent IS NULL THEN 'REVIEW'
       WHEN PageCount >= 100000 AND FragmentationPercent >= 30 THEN 'REVIEW'
       WHEN PageDensityPercent IS NOT NULL AND PageDensityPercent < 70 THEN 'REVIEW'
       WHEN FragmentationPercent >= 30 THEN 'REBUILD_CANDIDATE'
       WHEN FragmentationPercent >= 10 THEN 'REORGANIZE_CANDIDATE'
       ELSE 'NO_ACTION'
     END,
     CASE
       WHEN PageCount >= 100000 AND FragmentationPercent >= 30 THEN 1
       WHEN PageDensityPercent IS NOT NULL AND PageDensityPercent < 70 THEN 2
       WHEN FragmentationPercent >= 30 THEN 3
       WHEN FragmentationPercent >= 10 THEN 4
       WHEN FragmentationPercent IS NULL THEN 5
       ELSE 7
     END,
     CASE
       WHEN FragmentationPercent IS NULL THEN N'Fragmentation unavailable; manual review'
       WHEN PageCount >= 100000 AND FragmentationPercent >= 30 THEN N'Large partition: estimate log, duration and availability before action'
       WHEN PageDensityPercent IS NOT NULL AND PageDensityPercent < 70 THEN N'Low page density: verify fill factor and workload before action'
       WHEN FragmentationPercent >= 30 THEN N'Fragmentation threshold met; candidate only, not execution approval'
       WHEN FragmentationPercent >= 10 THEN N'Moderate fragmentation; candidate only'
       ELSE N'Below preliminary fragmentation threshold'
     END
  FROM #AuditStage;

  UPDATE im.AuditRun SET CompletedAtUtc=SYSUTCDATETIME(),Status='Completed'
   WHERE AuditRunId=@auditRunId;

  SELECT @auditRunId AS AuditRunId,@DatabaseName AS DatabaseName,
      COUNT_BIG(*) AS AssessedPartitions,
      SUM(CASE WHEN Classification='REBUILD_CANDIDATE' THEN CONVERT(bigint,1) ELSE 0 END) AS RebuildCandidates,
      SUM(CASE WHEN Classification='REORGANIZE_CANDIDATE' THEN CONVERT(bigint,1) ELSE 0 END) AS ReorganizeCandidates,
      SUM(CASE WHEN Classification='REVIEW' THEN CONVERT(bigint,1) ELSE 0 END) AS ManualReview
  FROM im.IndexAssessment WHERE AuditRunId=@auditRunId;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK;
  IF @auditRunId IS NOT NULL
    UPDATE im.AuditRun SET CompletedAtUtc=SYSUTCDATETIME(),Status='Failed',
        ErrorMessage=LEFT(ERROR_MESSAGE(),4000) WHERE AuditRunId=@auditRunId;
  THROW;
 END CATCH;
END;
GO
