USE [SQLManiakIndexMaintenance];
GO
CREATE OR ALTER PROCEDURE im.ClassifyRemoteAudit @RunId bigint
AS
BEGIN
 SET XACT_ABORT ON;SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM im.AuditRun WHERE AuditRunId=@RunId AND Status='Running')
 THROW 51030,'Audit not running',1;
 BEGIN TRAN;
 DELETE FROM im.IndexAssessment WHERE AuditRunId=@RunId;
 INSERT im.IndexAssessment
 (AuditRunId,ObjectId,IndexId,PartitionNumber,SchemaName,TableName,IndexName,
 IndexType,PageCount,FragmentationPercent,PageDensityPercent,MeasurementMode,
 Classification,Priority,Reason)
 SELECT s.AuditRunId,s.ObjectId,s.IndexId,s.PartitionNumber,s.SchemaName,s.TableName,s.IndexName,
 s.IndexType,s.PageCount,s.FragmentationPercent,s.PageDensityPercent,s.MeasurementMode,
 CASE WHEN s.FragmentationPercent IS NULL THEN 'REVIEW'
 WHEN s.PageCount>=100000 AND s.FragmentationPercent>=30 THEN 'REVIEW'
 WHEN s.PageDensityPercent<70 THEN 'REVIEW'
 WHEN s.FragmentationPercent>=30 THEN 'REBUILD_CANDIDATE'
 WHEN s.FragmentationPercent>=10 THEN 'REORGANIZE_CANDIDATE'
 ELSE 'NO_ACTION' END,
 CASE WHEN s.PageCount>=100000 AND s.FragmentationPercent>=30 THEN 1
 WHEN s.PageDensityPercent<70 THEN 2
 WHEN s.FragmentationPercent>=30 THEN 3
 WHEN s.FragmentationPercent>=10 THEN 4
 WHEN s.FragmentationPercent IS NULL THEN 5 ELSE 7 END,
 CASE WHEN s.FragmentationPercent IS NULL THEN N'Fragmentation measurement unavailable'
 WHEN s.PageCount>=100000 AND s.FragmentationPercent>=30 THEN N'Large partition: review execution cost'
 WHEN s.PageDensityPercent<70 THEN N'Low page density: review fill factor and workload'
 WHEN s.FragmentationPercent>=30 THEN N'Potential REBUILD; review before execution'
 WHEN s.FragmentationPercent>=10 THEN N'Potential REORGANIZE; review before execution'
 ELSE N'No action proposed' END
 FROM im.RemoteIndexStage s WHERE s.AuditRunId=@RunId;
 COMMIT;
END;
GO
