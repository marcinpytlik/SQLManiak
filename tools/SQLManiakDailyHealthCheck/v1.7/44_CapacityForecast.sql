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
            ELSE NULL END AS Headroom90DaysGB
FROM dhc.vCapacityFilegroupCurrent c
LEFT JOIN rates r ON r.ServerInstance=c.ServerInstance AND r.DatabaseName=c.DatabaseName
 AND r.FilegroupName=c.FilegroupName;
GO
