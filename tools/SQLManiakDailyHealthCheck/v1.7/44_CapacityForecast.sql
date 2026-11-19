/* Optional forecasting: at least 5 distinct samples spanning 7+ days.
   Uses USED GiB, not MDF autogrowth; linear forecast is advisory.
   Negative/zero growth has no exhaustion date.
   Data reorganization, file movement and shrink can invalidate the trend.
*/
USE SQLManiakHealthHistory;
GO
CREATE OR ALTER VIEW dhc.vCapacityForecast
AS
WITH samples AS (
 SELECT r.ServerInstance,f.DatabaseName,f.FilegroupName,r.RunId,r.StartedUTC,
        SUM(f.UsedGB) AS UsedGB,
        MAX(CASE WHEN f.UsedGB IS NULL THEN 1 ELSE 0 END) AS UnknownUsed
 FROM dhc.Run r
 JOIN dhc.CapacityFileSample f ON f.RunId=r.RunId
 WHERE r.Status='COMPLETE' AND f.FilegroupName IS NOT NULL
   AND r.StartedUTC>=DATEADD(DAY,-31,SYSUTCDATETIME())
 GROUP BY r.ServerInstance,f.DatabaseName,f.FilegroupName,r.RunId,r.StartedUTC
),
trend AS (
 SELECT ServerInstance,DatabaseName,FilegroupName,
        COUNT(*) AS Samples,
        MIN(StartedUTC) AS FirstSampleUTC,MAX(StartedUTC) AS LastSampleUTC,
        MAX(UnknownUsed) AS HasMissingMeasurements
 FROM samples
 GROUP BY ServerInstance,DatabaseName,FilegroupName
),
ends AS (
 SELECT t.*,s1.UsedGB AS FirstUsedGB,s2.UsedGB AS LastUsedGB
 FROM trend t
 OUTER APPLY (
  SELECT TOP(1) UsedGB FROM samples s
  WHERE s.ServerInstance=t.ServerInstance AND s.DatabaseName=t.DatabaseName
    AND s.FilegroupName=t.FilegroupName
  ORDER BY StartedUTC ASC,RunId ASC
 ) s1
 OUTER APPLY (
  SELECT TOP(1) UsedGB FROM samples s
  WHERE s.ServerInstance=t.ServerInstance AND s.DatabaseName=t.DatabaseName
    AND s.FilegroupName=t.FilegroupName
  ORDER BY StartedUTC DESC,RunId DESC
 ) s2
),
rates AS (
 SELECT *,
  CASE WHEN Samples>=5 AND HasMissingMeasurements=0
         AND DATEDIFF(SECOND,FirstSampleUTC,LastSampleUTC)>=7*86400
       THEN (LastUsedGB-FirstUsedGB) /
        NULLIF(DATEDIFF(SECOND,FirstSampleUTC,LastSampleUTC)/86400.0,0)
       ELSE NULL END AS NetGrowthGBPerDay
 FROM ends
)
SELECT c.ServerInstance,c.DatabaseName,c.FilegroupName,c.SampleUTC,
       c.AllocatedGB,c.UsedGB,c.InternalFreeGB,c.CurrentGrowthGB,
       c.FutureVolumeExtensionGB,c.EffectiveHeadroomGB,
       c.UnknownCapacity,c.Assessment,c.RecommendedAction,
       r.Samples,r.FirstSampleUTC,r.LastSampleUTC,r.NetGrowthGBPerDay,
       CASE WHEN r.NetGrowthGBPerDay>0 AND c.EffectiveHeadroomGB IS NOT NULL
            THEN CAST(c.EffectiveHeadroomGB/r.NetGrowthGBPerDay AS decimal(19,1))
            ELSE NULL END AS DaysToFull,
       CASE WHEN r.NetGrowthGBPerDay IS NULL THEN 'INSUFFICIENT HISTORY'
            WHEN r.NetGrowthGBPerDay<=0 THEN 'NO POSITIVE NET GROWTH'
            WHEN c.EffectiveHeadroomGB IS NULL THEN 'UNKNOWN CAPACITY'
            ELSE 'LINEAR ESTIMATE' END AS ForecastStatus,
       CASE WHEN r.NetGrowthGBPerDay IS NOT NULL
            THEN CAST(c.InternalFreeGB+c.CurrentGrowthGB-30*r.NetGrowthGBPerDay AS decimal(19,2))
            ELSE NULL END AS Headroom30DaysGB,
       CASE WHEN r.NetGrowthGBPerDay IS NOT NULL
            THEN CAST(c.InternalFreeGB+c.CurrentGrowthGB-60*r.NetGrowthGBPerDay AS decimal(19,2))
            ELSE NULL END AS Headroom60DaysGB,
       CASE WHEN r.NetGrowthGBPerDay IS NOT NULL
            THEN CAST(c.InternalFreeGB+c.CurrentGrowthGB-90*r.NetGrowthGBPerDay AS decimal(19,2))
            ELSE NULL END AS Headroom90DaysGB,
       CASE WHEN r.NetGrowthGBPerDay IS NULL THEN 'INSUFFICIENT HISTORY'
            WHEN c.EffectiveHeadroomGB IS NULL THEN 'UNKNOWN CAPACITY'
            WHEN r.NetGrowthGBPerDay<=0 THEN 'NO POSITIVE NET GROWTH'
            WHEN c.EffectiveHeadroomGB<=7*r.NetGrowthGBPerDay THEN 'CRITICAL'
            WHEN c.EffectiveHeadroomGB<=30*r.NetGrowthGBPerDay THEN 'WARNING'
            WHEN c.EffectiveHeadroomGB<=60*r.NetGrowthGBPerDay THEN 'REVIEW'
            ELSE 'OK' END AS ForecastAssessment,
       CASE WHEN r.NetGrowthGBPerDay IS NULL THEN 'INSUFFICIENT HISTORY'
            WHEN c.EffectiveHeadroomGB IS NULL THEN 'INSUFFICIENT DATA'
            WHEN r.NetGrowthGBPerDay>0 AND c.EffectiveHeadroomGB<=60*r.NetGrowthGBPerDay
              THEN CASE WHEN c.CurrentGrowthGB>100 THEN 'EXTEND EXISTING FILE'
                        WHEN c.GrowthBlockedFiles>0 THEN 'INCREASE MAXSIZE / CHECK STORAGE'
                        WHEN c.ExtendableVolumeCount>0 THEN 'EXTEND VOLUME'
                        ELSE 'ADD FILE RECOMMENDED - VERIFY STORAGE' END
            ELSE c.RecommendedAction END AS ForecastRecommendedAction
FROM dhc.vCapacityFilegroupCurrent c
LEFT JOIN rates r ON r.ServerInstance=c.ServerInstance AND r.DatabaseName=c.DatabaseName
 AND r.FilegroupName=c.FilegroupName;
GO

/* Current log usage is DATABASE-wide; LDF size/growth limits are FILE-wide.
   They are intentionally reported separately (not allocated per LDF). */
CREATE OR ALTER VIEW dhc.vCapacityLogCurrent
AS
WITH logruns AS (
 SELECT r.ServerInstance,r.RunId,r.StartedUTC,l.DatabaseName,
  l.AllocatedLogGB,l.UsedLogGB,l.UsedLogPct,l.LogReuseWait,l.RecoveryModel,
  ROW_NUMBER() OVER(
   PARTITION BY r.ServerInstance,l.DatabaseName
   ORDER BY r.StartedUTC DESC,r.RunId DESC) AS rn
 FROM dhc.Run r JOIN dhc.CapacityLogSample l ON l.RunId=r.RunId
 WHERE r.Status IN ('COMPLETE','PARTIAL')
),
logfiles AS (
 SELECT RunId,DatabaseName,COUNT(*) AS LogFileCount,
 SUM(CASE WHEN IsGrowthEnabled=0 OR
  (MaxSizeGB IS NOT NULL AND MaxSizeGB<=AllocatedGB)
  THEN 1 ELSE 0 END) AS GrowthBlockedFiles,
 MIN(VolumeFreeGB) AS MinVolumeFreeGB,
 SUM(AllocatedGB) AS AllocatedLogFilesGB
 FROM dhc.CapacityFileSample
 WHERE FileType='LOG'
 GROUP BY RunId,DatabaseName
)
SELECT l.ServerInstance,l.DatabaseName,l.StartedUTC,
 l.AllocatedLogGB,l.UsedLogGB,l.UsedLogPct,l.LogReuseWait,l.RecoveryModel,
 f.LogFileCount,f.GrowthBlockedFiles,f.MinVolumeFreeGB,f.AllocatedLogFilesGB,
 CASE WHEN l.UsedLogPct>=95 THEN 'CRITICAL'
      WHEN l.UsedLogPct>=85 THEN 'WARNING'
      WHEN l.UsedLogPct IS NULL THEN 'UNKNOWN'
      ELSE 'OK' END AS Assessment,
 CASE WHEN l.UsedLogPct IS NULL THEN 'VERIFY LOG MEASUREMENT'
      WHEN l.UsedLogPct>=85 AND l.LogReuseWait NOT IN ('NOTHING','CHECKPOINT')
      THEN 'INVESTIGATE LOG REUSE WAIT'
      WHEN l.UsedLogPct>=85 AND ISNULL(f.GrowthBlockedFiles,0)>0
      THEN 'INCREASE MAXSIZE / EXTEND STORAGE'
      WHEN l.UsedLogPct>=85 THEN 'PLAN LOG CAPACITY'
      ELSE 'MONITOR' END AS RecommendedAction
FROM logruns l LEFT JOIN logfiles f
 ON f.RunId=l.RunId AND f.DatabaseName=l.DatabaseName
WHERE l.rn=1;
GO
