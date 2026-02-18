/* SQL Agent jobs health:
   1) failed job runs (last 24h)
   2) jobs with schedule that did not run recently (heuristic)
*/
SET NOCOUNT ON;

-- 1) Failed runs in last 24 hours
SELECT TOP (200)
    j.name AS JobName,
    msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime,
    h.step_id,
    h.step_name,
    h.run_status,
    h.run_duration,
    h.message
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
WHERE h.run_status = 0
  AND msdb.dbo.agent_datetime(h.run_date, h.run_time) >= DATEADD(HOUR, -24, SYSDATETIME())
ORDER BY RunDateTime DESC;

PRINT '---';

-- 2) Jobs with schedules that have not executed in a while (last run older than 2 days) - tweak threshold
;WITH last_run AS
(
    SELECT
        j.job_id,
        MAX(msdb.dbo.agent_datetime(h.run_date, h.run_time)) AS last_run_dt
    FROM msdb.dbo.sysjobs j
    LEFT JOIN msdb.dbo.sysjobhistory h
      ON h.job_id = j.job_id
     AND h.step_id = 0  -- job outcome row
    GROUP BY j.job_id
)
SELECT
    j.name AS JobName,
    j.enabled,
    lr.last_run_dt AS LastRunDateTime,
    DATEDIFF(HOUR, lr.last_run_dt, SYSDATETIME()) AS HoursSinceLastRun
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobschedules js ON js.job_id = j.job_id
JOIN msdb.dbo.sysschedules s ON s.schedule_id = js.schedule_id AND s.enabled = 1
LEFT JOIN last_run lr ON lr.job_id = j.job_id
WHERE j.enabled = 1
  AND (lr.last_run_dt IS NULL OR lr.last_run_dt < DATEADD(DAY, -2, SYSDATETIME()))
ORDER BY HoursSinceLastRun DESC, j.name;
