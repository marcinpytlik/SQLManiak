/* DHC Capacity: non-destructive repository checks after installation and collection. */
USE SQLManiakHealthHistory;
SET NOCOUNT ON;
SELECT name,type_desc FROM sys.objects
WHERE schema_id=SCHEMA_ID('dhc') AND name IN
('CapacityFileSample','CapacityLogSample','VolumeCapacityPolicy',
 'vCapacityFilegroupCurrent','vCapacityForecast')
ORDER BY name;

SELECT TOP(100) r.ServerInstance,r.StartedUTC,
 f.DatabaseName,f.FileType,f.FilegroupName,f.LogicalFileName,
 f.AllocatedGB,f.UsedGB,f.InternalFreeGB,
 f.VolumeMountPoint,f.VolumeTotalGB,f.VolumeFreeGB,
 f.MaxSizeKind,f.MaxSizeGB,f.GrowthMB,f.IsPercentGrowth
FROM dhc.CapacityFileSample f JOIN dhc.Run r ON r.RunId=f.RunId
ORDER BY r.StartedUTC DESC,f.DatabaseName,f.FileId;

SELECT TOP(100) r.ServerInstance,r.StartedUTC,l.DatabaseName,
 l.AllocatedLogGB,l.UsedLogGB,l.UsedLogPct,l.LogReuseWait,l.RecoveryModel
FROM dhc.CapacityLogSample l JOIN dhc.Run r ON r.RunId=l.RunId
ORDER BY r.StartedUTC DESC,l.UsedLogPct DESC;

SELECT * FROM dhc.vCapacityFilegroupCurrent
ORDER BY EffectiveHeadroomGB,ServerInstance,DatabaseName,FilegroupName;

SELECT * FROM dhc.vCapacityLogCurrent ORDER BY UsedLogPct DESC;

SELECT * FROM dhc.vCapacityForecast
ORDER BY DaysToFull,ServerInstance,DatabaseName,FilegroupName;

-- Identify missing policies; do not assume volumes are extendable.
SELECT DISTINCT r.ServerInstance,f.VolumeMountPoint
FROM dhc.CapacityFileSample f JOIN dhc.Run r ON r.RunId=f.RunId
LEFT JOIN dhc.VolumeCapacityPolicy p
 ON p.ServerInstance=r.ServerInstance AND p.VolumeMountPoint=f.VolumeMountPoint
WHERE p.ServerInstance IS NULL
ORDER BY r.ServerInstance,f.VolumeMountPoint;

-- Example only, NOT executed: match both the actual @@SERVERNAME/VNN endpoint
-- used by collector and exact volume_mount_point returned above.
-- INSERT dhc.VolumeCapacityPolicy
--  (ServerInstance,VolumeMountPoint,CanExtend,MaxVolumeGB,SafetyReserveGB,Notes)
-- VALUES (N'FCI_A',N'G:\',0,NULL,150,N'Fixed volume');
-- INSERT dhc.VolumeCapacityPolicy
--  (ServerInstance,VolumeMountPoint,CanExtend,MaxVolumeGB,SafetyReserveGB,Notes)
-- VALUES (N'FCI_A',N'P:\',1,6144,150,N'Cap at 6 TiB');
