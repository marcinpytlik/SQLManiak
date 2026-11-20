USE [DBACentralRepositoryv4];
GO
/* Inventory v4 stage 2: extended metadata and robust category coverage. */
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('inventory.InventorySnapshot') AND name='CK_v4_Snapshot_Category')
 ALTER TABLE inventory.InventorySnapshot DROP CONSTRAINT CK_v4_Snapshot_Category;
GO
ALTER TABLE inventory.InventorySnapshot WITH CHECK
 ADD CONSTRAINT CK_v4_Snapshot_Category CHECK (Category IN
 ('INSTANCE','CONFIGURATION','DATABASE','DATABASE_FILE','TEMPDB','OBJECT','INDEX','STATISTICS',
  'SQL_AGENT_JOB','SQL_AGENT_STEP','SQL_AGENT_SCHEDULE','LOGIN','SERVER_ROLE','SERVER_PERMISSION',
  'DATABASE_USER','DATABASE_ROLE','DATABASE_PERMISSION','LINKED_SERVER','CREDENTIAL_METADATA',
  'HA_CLUSTER','HA_REPLICA','HA_DATABASE','BACKUP_POLICY','VOLUME','SERVICE',
  'INDEX_PARTITION','PARTITION_FUNCTION','PARTITION_SCHEME','TRACE_FLAG',
  'SCHEMA','COLUMN','INDEX_COLUMN','STATISTICS_COLUMN','FOREIGN_KEY'));
GO
IF OBJECT_ID(N'inventory.ScanCategory',N'U') IS NULL
BEGIN
 CREATE TABLE inventory.ScanCategory(
  ScanRunId bigint NOT NULL REFERENCES inventory.ScanRun(ScanRunId),
  Category varchar(32) NOT NULL,
  CategoryStatus varchar(12) NOT NULL,
  RowCount bigint NOT NULL,
  RecordedUtc datetime2(0) NOT NULL CONSTRAINT DF_v4_Category_Recorded DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_v4_ScanCategory PRIMARY KEY(ScanRunId,Category),
  CONSTRAINT CK_v4_Category_Status CHECK(CategoryStatus IN('COMPLETE','PARTIAL')),
  CONSTRAINT CK_v4_Category_Rows CHECK(RowCount>=0)
 );
END;
GO
IF OBJECT_ID(N'inventory.ChangeEvent',N'U') IS NULL
BEGIN
 CREATE TABLE inventory.ChangeEvent (
  ChangeEventId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_v4_ChangeEvent PRIMARY KEY,
  PreviousScanRunId bigint NOT NULL REFERENCES inventory.ScanRun(ScanRunId),
  ScanRunId bigint NOT NULL REFERENCES inventory.ScanRun(ScanRunId),
  Category varchar(32) NOT NULL,
  EntityKey nvarchar(900) NOT NULL,
  ChangeType varchar(12) NOT NULL,
  OldJson nvarchar(max) NULL,
  NewJson nvarchar(max) NULL,
  DetectedUtc datetime2(0) NOT NULL CONSTRAINT DF_v4_Change_Utc DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_v4_Change_Type CHECK(ChangeType IN('ADDED','REMOVED','MODIFIED'))
 );
 CREATE INDEX IX_v4_Change_Scan ON inventory.ChangeEvent(ScanRunId,Category,ChangeType);
END;
GO
/* Only two COMPLETE scans and the categories explicitly marked COMPLETE in both.
   This prevents false REMOVED findings after privilege errors or skipped collectors. */
CREATE OR ALTER PROCEDURE inventory.usp_CompareCompletedScans
 @ScanRunId bigint
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 DECLARE @InstanceId bigint, @PreviousScanRunId bigint;
 SELECT @InstanceId=InstanceId FROM inventory.ScanRun
  WHERE ScanRunId=@ScanRunId AND ScanStatus='COMPLETE';
 IF @InstanceId IS NULL THROW 54100,'Current scan must be COMPLETE.',1;
 SELECT TOP(1) @PreviousScanRunId=ScanRunId
 FROM inventory.ScanRun
 WHERE InstanceId=@InstanceId AND ScanStatus='COMPLETE' AND ScanRunId<>@ScanRunId
  AND EXISTS (SELECT 1 FROM inventory.ScanCategory sc WHERE sc.ScanRunId=inventory.ScanRun.ScanRunId)
  AND StartedUtc < (SELECT StartedUtc FROM inventory.ScanRun WHERE ScanRunId=@ScanRunId)
 ORDER BY StartedUtc DESC,ScanRunId DESC;
 IF @PreviousScanRunId IS NULL
 BEGIN
  SELECT @ScanRunId AS ScanRunId, CAST(NULL AS bigint) AS PreviousScanRunId,
    CAST(0 AS bigint) AS Changes, N'BASELINE_ONLY' AS Result;
  RETURN;
 END;

 BEGIN TRANSACTION;
 DELETE FROM inventory.ChangeEvent WHERE ScanRunId=@ScanRunId;
 ;WITH SafeCategories AS(
  SELECT n.Category
  FROM inventory.ScanCategory n
  INNER JOIN inventory.ScanCategory p
    ON p.Category=n.Category AND p.ScanRunId=@PreviousScanRunId
   AND p.CategoryStatus='COMPLETE'
  WHERE n.ScanRunId=@ScanRunId AND n.CategoryStatus='COMPLETE'
 ),
 Diff AS (
  SELECT COALESCE(n.Category,p.Category) AS Category,
   COALESCE(n.EntityKey,p.EntityKey) AS EntityKey,
   p.DataJson AS OldJson,n.DataJson AS NewJson,
   CASE
    WHEN p.InventorySnapshotId IS NULL THEN 'ADDED'
    WHEN n.InventorySnapshotId IS NULL THEN 'REMOVED'
    ELSE 'MODIFIED'
   END AS ChangeType
  FROM (SELECT * FROM inventory.InventorySnapshot WHERE ScanRunId=@PreviousScanRunId) p
  FULL OUTER JOIN (SELECT * FROM inventory.InventorySnapshot WHERE ScanRunId=@ScanRunId) n
   ON n.Category=p.Category AND n.EntityKey=p.EntityKey
  WHERE EXISTS (SELECT 1 FROM SafeCategories c WHERE c.Category=COALESCE(n.Category,p.Category))
   AND (p.InventorySnapshotId IS NULL OR n.InventorySnapshotId IS NULL
     OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),p.DataJson))
      <> HASHBYTES('SHA2_256',CONVERT(varbinary(max),n.DataJson)))
 )
 INSERT inventory.ChangeEvent(PreviousScanRunId,ScanRunId,Category,EntityKey,ChangeType,OldJson,NewJson)
 SELECT @PreviousScanRunId,@ScanRunId,Category,EntityKey,ChangeType,OldJson,NewJson FROM Diff;
 DECLARE @count bigint=@@ROWCOUNT;
 COMMIT;
 SELECT @ScanRunId AS ScanRunId,@PreviousScanRunId AS PreviousScanRunId,
  @count AS Changes,N'COMPARED' AS Result;
END;
GO
CREATE OR ALTER VIEW report.vInventoryChanges AS
SELECT c.ChangeEventId,c.DetectedUtc,i.ServerInstance,c.PreviousScanRunId,
 c.ScanRunId,c.Category,c.EntityKey,c.ChangeType,c.OldJson,c.NewJson
FROM inventory.ChangeEvent c
JOIN inventory.ScanRun r ON c.ScanRunId=r.ScanRunId
JOIN inventory.Instance i ON i.InstanceId=r.InstanceId;
GO
