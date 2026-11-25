/* SQLManiak DHC v1.7 - monitoring status checks (read-only).
   Run on repository after 09_MonitoringStatus.sql.
   Does not alter inventory, execution history, or Docker containers.
*/
USE SQLManiakHealthHistory;
GO
-- A: One status row per registered instance.
SELECT
    s.ServerId,s.ServerInstance,s.IsEnabled,s.IntervalMinutes,
    s.MonitoringStatus,s.IsOverdue,
    s.LastExecutionStatus,s.LastAttemptUTC,s.LastCompleteUTC,
    s.MinutesSinceAttempt,s.MinutesSinceComplete,s.LastRunId,
    LEFT(s.LastErrorText,300) AS LastErrorPreview
FROM dhc.vMonitoringStatus AS s
ORDER BY s.Environment,s.ServerInstance;
GO
-- B: Totals must equal inventory count; this detects duplication or missing rows.
SELECT
    (SELECT COUNT_BIG(*) FROM dhc.MonitoredServer) AS Registered,
    (SELECT COUNT_BIG(*) FROM dhc.vMonitoringStatus) AS StatusRows,
    CASE WHEN (SELECT COUNT_BIG(*) FROM dhc.MonitoredServer)
              = (SELECT COUNT_BIG(*) FROM dhc.vMonitoringStatus)
         THEN 'PASS' ELSE 'FAILED' END AS CardinalityCheck;
GO
-- C: All actual latest attempts must match the view (independent reconciliation).
WITH ActualLatest AS
(
 SELECT e.ServerInstance,e.ExecutionId,e.Status,
        ROW_NUMBER() OVER (PARTITION BY e.ServerInstance
                           ORDER BY e.StartedUTC DESC,e.ExecutionId DESC) AS rn
 FROM dhc.ExecutionLog AS e
)
SELECT s.ServerInstance,s.MonitoringStatus,s.LastExecutionStatus,
       a.Status AS ActualLatestStatus,
       CASE WHEN (a.ExecutionId=s.LastExecutionId)
                OR (a.ExecutionId IS NULL AND s.LastExecutionId IS NULL)
            THEN 'PASS' ELSE 'FAILED' END AS LastAttemptCheck
FROM dhc.vMonitoringStatus AS s
LEFT JOIN ActualLatest AS a
 ON a.ServerInstance=s.ServerInstance AND a.rn=1
ORDER BY s.ServerInstance;
GO
-- D: By-environment totals and operational exceptions.
SELECT * FROM dhc.vMonitoringSummary ORDER BY Environment;
SELECT ServerInstance,Environment,MonitoringStatus,IsOverdue,
       LastAttemptUTC,LastCompleteUTC,MinutesSinceComplete,LastErrorText
FROM dhc.vMonitoringStatus
WHERE IsEnabled=1
  AND (MonitoringStatus IN ('FAILED','PARTIAL','NO_DATA','RUNNING') OR IsOverdue=1)
ORDER BY IsOverdue DESC,ServerInstance;
GO
