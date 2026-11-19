/* DHC v1.7 capacity repository extension (administrator, repository instance).
   Additive and re-runnable. This script does not collect source measurements.
   All GB values are GiB (1024 MiB). */
USE SQLManiakHealthHistory;
GO
IF OBJECT_ID(N'dhc.CapacityFileSample',N'U') IS NULL
CREATE TABLE dhc.CapacityFileSample(
 RunId uniqueidentifier NOT NULL REFERENCES dhc.Run(RunId),
 DatabaseName sysname NOT NULL,
 DatabaseId int NOT NULL,FileId int NOT NULL,
 FileType varchar(12) NOT NULL,FilegroupName sysname NULL,LogicalFileName sysname NOT NULL,
 PhysicalName nvarchar(260) NOT NULL,VolumeMountPoint nvarchar(512) NULL,
 AllocatedGB decimal(19,3) NOT NULL,UsedGB decimal(19,3) NULL,
 InternalFreeGB decimal(19,3) NULL,
 VolumeTotalGB decimal(19,3) NULL,VolumeFreeGB decimal(19,3) NULL,
 MaxSizeGB decimal(19,3) NULL,MaxSizeKind varchar(16) NOT NULL,
 GrowthMB decimal(19,2) NULL,IsPercentGrowth bit NOT NULL,IsGrowthEnabled bit NOT NULL,
 CONSTRAINT PK_CapacityFileSample PRIMARY KEY(RunId,DatabaseId,FileId));
GO
IF OBJECT_ID(N'dhc.CapacityLogSample',N'U') IS NULL
CREATE TABLE dhc.CapacityLogSample(
 RunId uniqueidentifier NOT NULL REFERENCES dhc.Run(RunId),
 DatabaseName sysname NOT NULL,DatabaseId int NOT NULL,
 AllocatedLogGB decimal(19,3) NULL,UsedLogGB decimal(19,3) NULL,
 UsedLogPct decimal(9,3) NULL,LogReuseWait nvarchar(60) NULL,
 RecoveryModel nvarchar(60) NULL,
 CONSTRAINT PK_CapacityLogSample PRIMARY KEY(RunId,DatabaseId));
GO
IF OBJECT_ID(N'dhc.VolumeCapacityPolicy',N'U') IS NULL
CREATE TABLE dhc.VolumeCapacityPolicy(
 ServerInstance nvarchar(256) NOT NULL,
 VolumeMountPoint nvarchar(512) NOT NULL,
 CanExtend bit NOT NULL,
 MaxVolumeGB decimal(19,3) NULL,
 SafetyReserveGB decimal(19,3) NOT NULL CONSTRAINT DF_DHCCapSafety DEFAULT(100),
 Notes nvarchar(1000) NULL,
 UpdatedUTC datetime2(3) NOT NULL CONSTRAINT DF_DHCCapUpdated DEFAULT(SYSUTCDATETIME()),
 CONSTRAINT PK_VolumeCapacityPolicy PRIMARY KEY(ServerInstance,VolumeMountPoint),
 CONSTRAINT CK_VolumePolicyMax CHECK (MaxVolumeGB IS NULL OR MaxVolumeGB>0),
 CONSTRAINT CK_VolumePolicyReserve CHECK (SafetyReserveGB>=0),
 CONSTRAINT CK_VolumePolicyExtend CHECK(CanExtend=0 OR MaxVolumeGB IS NOT NULL));
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dhc.CapacityFileSample') AND name='IX_DHCCapFileGroup')
 CREATE INDEX IX_DHCCapFileGroup ON dhc.CapacityFileSample(DatabaseName,FilegroupName,RunId)
 INCLUDE(UsedGB,AllocatedGB,InternalFreeGB,VolumeMountPoint,VolumeFreeGB,MaxSizeGB,IsGrowthEnabled);
GO
/* The same volume can host files from other databases/filegroups.
   Per-file volume free bytes are never summed without deduplicating mount point.
   Reserve for other consumers is NOT guaranteed; policy remains an advisory.
*/
CREATE OR ALTER VIEW dhc.vCapacityFilegroupCurrent
AS
WITH latest AS (
 SELECT ServerInstance,MAX(StartedUTC) AS StartedUTC
 FROM dhc.Run WHERE Status IN ('COMPLETE','PARTIAL')
 GROUP BY ServerInstance
),
base AS (
 SELECT r.ServerInstance,r.StartedUTC,f.*,
  p.CanExtend,p.MaxVolumeGB,p.SafetyReserveGB,
  CASE WHEN p.ServerInstance IS NULL THEN 1 ELSE 0 END AS PolicyMissing,
  CASE WHEN f.MaxSizeKind='NO_GROWTH' OR f.IsGrowthEnabled=0 THEN CONVERT(decimal(19,3),0)
       WHEN f.MaxSizeGB IS NULL THEN CONVERT(decimal(19,3),999999999)
       ELSE CASE WHEN f.MaxSizeGB>f.AllocatedGB THEN f.MaxSizeGB-f.AllocatedGB
                 ELSE CONVERT(decimal(19,3),0) END END AS FileGrowthRoomGB
 FROM dhc.Run r
 JOIN latest x ON x.ServerInstance=r.ServerInstance AND x.StartedUTC=r.StartedUTC
 JOIN dhc.CapacityFileSample f ON f.RunId=r.RunId
 LEFT JOIN dhc.VolumeCapacityPolicy p ON p.ServerInstance=r.ServerInstance
      AND p.VolumeMountPoint=f.VolumeMountPoint
 WHERE r.Status IN ('COMPLETE','PARTIAL') AND f.FilegroupName IS NOT NULL
),
volume_group AS (
 SELECT ServerInstance,DatabaseName,FilegroupName,VolumeMountPoint,
  MAX(VolumeFreeGB) AS VolumeFreeGB,
  MAX(VolumeTotalGB) AS VolumeTotalGB,
  MAX(CONVERT(int,CanExtend)) AS CanExtend,MAX(MaxVolumeGB) AS MaxVolumeGB,
  MAX(SafetyReserveGB) AS SafetyReserveGB,
  MAX(PolicyMissing) AS PolicyMissing,
  SUM(FileGrowthRoomGB) AS ConfiguredGrowthGB,
  MAX(CASE WHEN VolumeMountPoint IS NULL OR VolumeFreeGB IS NULL THEN 1 ELSE 0 END) AS MetadataMissing
 FROM base GROUP BY ServerInstance,DatabaseName,FilegroupName,VolumeMountPoint
),
volume_room AS (
 SELECT *,
 CASE WHEN PolicyMissing=1 OR MetadataMissing=1 THEN NULL
      ELSE
       CASE WHEN ConfiguredGrowthGB <
             CASE WHEN VolumeFreeGB-ISNULL(SafetyReserveGB,0)>0
                  THEN VolumeFreeGB-ISNULL(SafetyReserveGB,0)
                  ELSE 0 END
            THEN ConfiguredGrowthGB
            ELSE CASE WHEN VolumeFreeGB-ISNULL(SafetyReserveGB,0)>0
                      THEN VolumeFreeGB-ISNULL(SafetyReserveGB,0) ELSE 0 END END
 END AS CurrentGrowthGB,
 CASE WHEN PolicyMissing=1 OR MetadataMissing=1 THEN NULL
      WHEN CanExtend=1 AND MaxVolumeGB>VolumeTotalGB
      THEN MaxVolumeGB-VolumeTotalGB ELSE CONVERT(decimal(19,3),0) END AS FutureVolumeExtensionGB
 FROM volume_group
),
fg AS (
 SELECT ServerInstance,DatabaseName,FilegroupName,COUNT(*) AS FileCount,
  SUM(AllocatedGB) AS AllocatedGB,SUM(UsedGB) AS UsedGB,
  SUM(InternalFreeGB) AS InternalFreeGB,
  MAX(CASE WHEN UsedGB IS NULL OR InternalFreeGB IS NULL THEN 1 ELSE 0 END) AS UsedMissing,
  SUM(CASE WHEN FileGrowthRoomGB=0 THEN 1 ELSE 0 END) AS GrowthBlockedFiles,
  MAX(StartedUTC) AS SampleUTC
 FROM base GROUP BY ServerInstance,DatabaseName,FilegroupName
),
room AS (
 SELECT ServerInstance,DatabaseName,FilegroupName,
  SUM(CurrentGrowthGB) AS CurrentGrowthGB,
  SUM(FutureVolumeExtensionGB) AS FutureVolumeExtensionGB,
  MAX(CASE WHEN CurrentGrowthGB IS NULL OR FutureVolumeExtensionGB IS NULL THEN 1 ELSE 0 END) AS UnknownCapacity,
  SUM(CASE WHEN CanExtend=1 AND FutureVolumeExtensionGB>0 THEN 1 ELSE 0 END) AS ExtendableVolumeCount,
  SUM(CASE WHEN PolicyMissing=1 THEN 1 ELSE 0 END) AS MissingPolicyCount
 FROM volume_room GROUP BY ServerInstance,DatabaseName,FilegroupName
)
SELECT f.*,r.CurrentGrowthGB,r.FutureVolumeExtensionGB,r.UnknownCapacity,r.ExtendableVolumeCount,r.MissingPolicyCount,
 CASE WHEN f.UsedMissing=1 OR r.UnknownCapacity=1 THEN NULL
 ELSE f.InternalFreeGB+r.CurrentGrowthGB END AS EffectiveHeadroomGB,
 CASE WHEN f.UsedMissing=1 OR r.UnknownCapacity=1 THEN 'INSUFFICIENT DATA'
 WHEN f.InternalFreeGB+r.CurrentGrowthGB<100 THEN 'CRITICAL'
 WHEN f.InternalFreeGB+r.CurrentGrowthGB<500 THEN 'WARNING'
 WHEN f.InternalFreeGB/NULLIF(f.AllocatedGB,0)<0.10 THEN 'REVIEW'
 ELSE 'OK' END AS Assessment,
 CASE WHEN f.UsedMissing=1 OR r.UnknownCapacity=1 THEN 'INSUFFICIENT DATA'
 WHEN f.InternalFreeGB+r.CurrentGrowthGB>=500 THEN 'CAPACITY SUFFICIENT'
 WHEN r.CurrentGrowthGB>100 THEN 'EXTEND EXISTING FILE'
 WHEN f.GrowthBlockedFiles>0 AND r.CurrentGrowthGB=0 THEN 'INCREASE MAXSIZE / CHECK STORAGE'
 WHEN r.ExtendableVolumeCount>0 THEN 'EXTEND VOLUME'
 ELSE 'ADD FILE RECOMMENDED - VERIFY STORAGE' END AS RecommendedAction
FROM fg f JOIN room r ON r.ServerInstance=f.ServerInstance AND r.DatabaseName=f.DatabaseName AND r.FilegroupName=f.FilegroupName;
GO
