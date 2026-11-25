/* SQLManiak DHC v1.7 - monitoring of the monitoring.
   Install on Repository after 04_MonitoredServers.sql and 08_ExecutionLog.sql.
   Read-only views; safe to rerun and do not schedule or alter monitored targets.

   NO_DATA: no execution attempt has ever been logged for this endpoint.
   IsOverdue: enabled instance with no attempt by registration+IntervalMinutes,
              or no new attempt by last StartedUTC+IntervalMinutes.
   Note: IsOverdue measures ATTEMPT cadence, not successful measurements.
   LastCompleteUTC tracks last COMPLETE, independently of last attempt.
*/
USE SQLManiakHealthHistory;
GO
IF OBJECT_ID(N'dhc.MonitoredServer',N'U') IS NULL
 OR OBJECT_ID(N'dhc.ExecutionLog',N'U') IS NULL
    THROW 51020, 'Deploy 04_MonitoredServers.sql and 08_ExecutionLog.sql first.', 1;
GO
CREATE OR ALTER VIEW dhc.vMonitoringStatus
AS
SELECT
    s.ServerId,
    s.ServerInstance,
    s.DisplayName,
    s.Environment,
    s.MonitorGroup,
    s.IsEnabled,
    s.IntervalMinutes,
    s.CollectTempDB,
    s.CreatedUTC,
    l.ExecutionId AS LastExecutionId,
    l.StartedUTC AS LastAttemptUTC,
    l.FinishedUTC AS LastAttemptFinishedUTC,
    l.Status AS LastExecutionStatus,
    l.RunId AS LastRunId,
    l.RowsStored AS LastRowsStored,
    l.ErrorText AS LastErrorText,
    good.StartedUTC AS LastCompleteUTC,
    good.RunId AS LastCompleteRunId,
    calc.MinutesSinceAttempt,
    calc.MinutesSinceComplete,
    CONVERT(bit, CASE
       WHEN s.IsEnabled = 0 THEN 0
       WHEN calc.MinutesSinceAttempt > CONVERT(bigint,s.IntervalMinutes) THEN 1
       ELSE 0 END) AS IsOverdue,
    CASE
       WHEN s.IsEnabled = 0 THEN 'DISABLED'
       WHEN l.ExecutionId IS NULL THEN 'NO_DATA'
       WHEN l.Status = 'FAILED' THEN 'FAILED'
       WHEN l.Status = 'PARTIAL' THEN 'PARTIAL'
       WHEN l.Status = 'RUNNING' THEN 'RUNNING'
       WHEN l.Status = 'COMPLETE' THEN 'COMPLETE'
       ELSE 'UNKNOWN'
    END AS MonitoringStatus
FROM dhc.MonitoredServer AS s
OUTER APPLY (
    SELECT TOP (1)
        e.ExecutionId,e.StartedUTC,e.FinishedUTC,e.Status,
        e.RunId,e.RowsStored,e.ErrorText
    FROM dhc.ExecutionLog AS e
    WHERE e.ServerInstance = s.ServerInstance
    ORDER BY e.StartedUTC DESC,e.ExecutionId DESC
) AS l
OUTER APPLY (
    SELECT TOP (1) e.StartedUTC,e.RunId
    FROM dhc.ExecutionLog AS e
    WHERE e.ServerInstance=s.ServerInstance AND e.Status='COMPLETE'
    ORDER BY e.StartedUTC DESC,e.ExecutionId DESC
) AS good
CROSS APPLY (
    SELECT
       DATEDIFF_BIG(MINUTE,COALESCE(l.StartedUTC,s.CreatedUTC),SYSUTCDATETIME()) AS MinutesSinceAttempt,
       CASE WHEN good.StartedUTC IS NULL THEN NULL
            ELSE DATEDIFF_BIG(MINUTE,good.StartedUTC,SYSUTCDATETIME()) END AS MinutesSinceComplete
) AS calc;
GO
CREATE OR ALTER VIEW dhc.vMonitoringSummary
AS
SELECT
    Environment,
    COUNT_BIG(*) AS TotalServers,
    SUM(CONVERT(bigint,IsEnabled)) AS EnabledServers,
    SUM(CASE WHEN IsEnabled=1 AND MonitoringStatus='COMPLETE' AND IsOverdue=0 THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS CurrentComplete,
    SUM(CASE WHEN IsEnabled=1 AND MonitoringStatus='FAILED' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS Failed,
    SUM(CASE WHEN IsEnabled=1 AND MonitoringStatus='PARTIAL' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS Partial,
    SUM(CASE WHEN IsEnabled=1 AND MonitoringStatus='NO_DATA' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS NoData,
    SUM(CASE WHEN IsEnabled=1 AND IsOverdue=1 THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS Overdue,
    SUM(CASE WHEN IsEnabled=1 AND MonitoringStatus='RUNNING' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS Running
FROM dhc.vMonitoringStatus
GROUP BY Environment;
GO
SELECT ServerId,ServerInstance,Environment,MonitoringStatus,
       IsOverdue,LastAttemptUTC,LastCompleteUTC,MinutesSinceAttempt,
       MinutesSinceComplete,LastErrorText
FROM dhc.vMonitoringStatus
ORDER BY Environment,MonitorGroup,ServerInstance;
GO
SELECT * FROM dhc.vMonitoringSummary ORDER BY Environment;
GO
