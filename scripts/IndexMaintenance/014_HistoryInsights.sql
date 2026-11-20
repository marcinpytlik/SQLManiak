/*
 Read-only trend reports for legacy 30-day aggregates.
 Do not use fragment drops as proof of REBUILD; do not automatically approve queue.
*/
USE [SQLManiakIndexMaintenance];
GO
-- Largest consecutive-day fragmentation drops on similarly sized indexes
SELECT TOP (100) ServerName,DatabaseName,TableName,IndexName,
 PreviousMeasurementDate,MeasurementDate,PreviousFragmentationPct,
 AvgFragmentationPct,
 AvgFragmentationPct-PreviousFragmentationPct AS ChangePercentagePoints,
 MaxPageCount,SamplesInDay
FROM im.IndexHistoryDaily
WHERE PreviousMeasurementDate=DATEADD(day,-1,MeasurementDate)
 AND PreviousFragmentationPct-AvgFragmentationPct >= 20
 AND MaxPageCount>=1000
ORDER BY PreviousFragmentationPct-AvgFragmentationPct DESC;
GO
-- Recurrent high fragmentation: exploration only, not an execution approval
SELECT TOP (100) ServerName,DatabaseName,TableName,IndexName,
 COUNT_BIG(*) AS DaysObserved,
 SUM(CASE WHEN AvgFragmentationPct>=30 THEN CONVERT(bigint,1) ELSE 0 END) AS DaysOver30Pct,
 MAX(MaxPageCount) AS MaxPages,
 MIN(MeasurementDate) AS FirstDay,MAX(MeasurementDate) AS LastDay
FROM im.IndexHistoryDaily
GROUP BY ServerName,DatabaseName,TableName,IndexName
HAVING COUNT_BIG(*)>=10
ORDER BY DaysOver30Pct DESC,MaxPages DESC;
GO
