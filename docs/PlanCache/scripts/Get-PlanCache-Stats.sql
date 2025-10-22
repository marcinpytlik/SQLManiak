/* Get-PlanCache-Stats.sql
   Statystyki plan cache wg typu planu i rozmiaru.
*/
SET NOCOUNT ON;

SELECT
    cp.objtype,
    COUNT(*)                          AS Plans,
    SUM(cp.usecounts)                 AS TotalUseCounts,
    SUM(cp.size_in_bytes)/1024/1024.0 AS SizeMB,
    SUM(CASE WHEN cp.objtype = 'Adhoc' THEN 1 ELSE 0 END) AS AdHocCount
FROM sys.dm_exec_cached_plans AS cp
GROUP BY cp.objtype
ORDER BY SizeMB DESC;
