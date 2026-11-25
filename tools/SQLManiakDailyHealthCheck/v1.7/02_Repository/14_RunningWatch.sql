/* SQLManiak DHC v1.7 - stale RUNNING diagnostic, read-only.
   Deploy on SQLManiakHealthHistory after 08_ExecutionLog.sql.
   A long-running attempt is SUSPECTED, not proven orphaned.
   No UPDATE/DELETE/unlock or automatic restart.
*/
USE SQLManiakHealthHistory;
GO
IF OBJECT_ID(N'dhc.ExecutionLog',N'U') IS NULL
    THROW 51050,'Install 08_ExecutionLog.sql first.',1;
GO
CREATE OR ALTER PROCEDURE dhc.GetRunningWatch
    @MinAgeMinutes int=60,
    @IncludeRecent bit=0
AS
BEGIN
 SET NOCOUNT ON;
 IF @MinAgeMinutes NOT BETWEEN 1 AND 10080
    THROW 51051,'MinAgeMinutes must be between 1 and 10080.',1;

 DECLARE @Now datetime2(3)=SYSUTCDATETIME();
 SELECT
    e.ExecutionId,e.ServerId,e.ServerInstance,
    e.StartedUTC,e.Status,
    DATEDIFF_BIG(SECOND,e.StartedUTC,@Now) AS AgeSeconds,
    DATEDIFF_BIG(MINUTE,e.StartedUTC,@Now) AS AgeMinutes,
    CONVERT(bit,CASE WHEN e.StartedUTC<=DATEADD(MINUTE,-@MinAgeMinutes,@Now)
                     THEN 1 ELSE 0 END) AS SuspectedStale,
    s.Environment,s.IsEnabled,
    @MinAgeMinutes AS ThresholdMinutes
 FROM dhc.ExecutionLog AS e
 LEFT JOIN dhc.MonitoredServer AS s ON s.ServerId=e.ServerId
 WHERE e.Status='RUNNING'
   AND (@IncludeRecent=1 OR e.StartedUTC<=DATEADD(MINUTE,-@MinAgeMinutes,@Now))
 ORDER BY e.StartedUTC,e.ExecutionId;
END;
GO
EXEC dhc.GetRunningWatch @MinAgeMinutes=60, @IncludeRecent=1;
GO
