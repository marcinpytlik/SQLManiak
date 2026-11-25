/*
 SQLManiak Daily Health Check 1.5 / CSV
 SQL Server 2022+ (Windows / FCI)
 Core diagnostics read-only; opt-in history writes to SQLManiakHealthHistory only.
 No server configuration changes, job modifications, backup or maintenance.
 Execute in SSMS as a login with adequate server-level and msdb permissions.
 SQL Server 2022: VIEW SERVER PERFORMANCE STATE required for some DMVs;
 reading error logs requires VIEW ANY ERROR LOG or sufficient elevated rights.
 msdb SQL Agent history visibility depends on msdb SQLAgentReaderRole / sysadmin.
 All times are SQL Server local time.
*/
SET NOCOUNT ON;
DECLARE @Now datetime2(0) = SYSDATETIME();
DECLARE @Since datetime2(0) = DATEADD(HOUR,-24,@Now);
DECLARE @DiskWarningPercent decimal(5,2) = 20.0;
DECLARE @DiskCriticalPercent decimal(5,2) = 10.0;
DECLARE @LogWarningPercent decimal(5,2) = 75.0;
DECLARE @LogCriticalPercent decimal(5,2) = 90.0;
DECLARE @FullBackupMaxHours int = 26;
DECLARE @LogBackupMaxMinutes int = 30;
DECLARE @BlockingWarningSeconds int = 30;
DECLARE @RunningJobWarningMinutes int = 120;
DECLARE @ErrorLogFilesToScan int = 3; -- 0=current, 1..2 archived; max 7 supported
DECLARE @ShowErrorLogRows int = 200;
DECLARE @SaveHistory bit = 0;             -- 0: no writes; 1: save measurement if history DB deployed
DECLARE @MissingJobGraceMinutes int = 20; -- ignore runs scheduled in the last 20 minutes
DECLARE @JobStartToleranceMinutes int = 15;
DECLARE @FileGrowthWarningGB decimal(18,2) = 10.0;  -- net file size increase since previous sample
DECLARE @DiskDeclineWarningGBPerDay decimal(18,2) = 20.0;
DECLARE @HistoryDatabase sysname = N'SQLManiakHealthHistory';
DECLARE @AutoGrowthFrequentCount int = 10;   -- events in available 24-hour trace
DECLARE @AutoGrowthSlowMs decimal(19,2) = 1000.0; -- longest event >= 1 s
DECLARE @AutoGrowthGrowthWarningMB decimal(19,2) = 10240.0; -- >= 10 GB / 24 h
-- Oversized LOG candidates: thresholds are diagnostic, never trigger SHRINK.
DECLARE @LogOversizeMinGB decimal(19,2) = 4.0;
DECLARE @LogOversizeMaxUsedPercent decimal(9,2) = 10.0;
DECLARE @LogOversizeMinRatio decimal(12,2) = 1.0;

IF @ErrorLogFilesToScan NOT BETWEEN 1 AND 7
    THROW 50001, '@ErrorLogFilesToScan must be between 1 and 7.', 1;

CREATE TABLE #Alerts
(
    Id int IDENTITY(1,1) PRIMARY KEY,
    Severity varchar(8) NOT NULL,
    Area varchar(32) NOT NULL,
    ObjectName nvarchar(256) NULL,
    Details nvarchar(2000) NOT NULL
);

PRINT 'SQLManiak Daily Health Check -- '+CONVERT(varchar(19),@Now,120);

/* 1. Instance metadata */
BEGIN TRY
    SELECT '01 INSTANCE' AS Section,
           @@SERVERNAME AS SqlServerName,
           CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS ConnectedInstance,
           CONVERT(nvarchar(128),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) AS ActiveNode,
           CONVERT(int,SERVERPROPERTY('IsClustered')) AS IsClustered,
           CONVERT(nvarchar(128),SERVERPROPERTY('ProductVersion')) AS ProductVersion,
           CONVERT(nvarchar(128),SERVERPROPERTY('ProductLevel')) AS ProductLevel,
           si.sqlserver_start_time AS SqlServerStartTime,
           @Since AS FromTime, @Now AS ToTime
    FROM sys.dm_os_sys_info si;
END TRY
BEGIN CATCH
    INSERT #Alerts VALUES ('WARNING','INSTANCE',NULL,ERROR_MESSAGE());
END CATCH;

/* 1b. Service status; requires VIEW SERVER SECURITY STATE in SQL Server 2022 */
BEGIN TRY
    SELECT '01B SERVICES' AS Section,servicename,status_desc,startup_type_desc,
           last_startup_time,is_clustered,cluster_nodename
    FROM sys.dm_server_services;

    INSERT #Alerts
    SELECT 'CRITICAL','SERVICE',servicename,
           CONCAT('Service status: ',status_desc,'; startup: ',startup_type_desc)
    FROM sys.dm_server_services
    WHERE servicename LIKE N'SQL Server Agent%'
      AND status_desc <> N'Running';
END TRY
BEGIN CATCH
    INSERT #Alerts VALUES ('WARNING','SERVICE',NULL,ERROR_MESSAGE());
END CATCH;

/* 2. ERRORLOG files 0..N: scan archived files too, to handle restarts and cycling */
CREATE TABLE #ErrorLogRaw (LogDate datetime NULL, ProcessInfo nvarchar(100) NULL, [Text] nvarchar(max) NULL);
DECLARE @LogNumber int=0;
WHILE @LogNumber < @ErrorLogFilesToScan
BEGIN
    BEGIN TRY
        INSERT INTO #ErrorLogRaw (LogDate,ProcessInfo,[Text])
        EXEC master.dbo.xp_readerrorlog @LogNumber,1,NULL,NULL,@Since,@Now,N'desc';
    END TRY
    BEGIN CATCH
        INSERT #Alerts VALUES ('WARNING','ERRORLOG',CONCAT('Archive ',@LogNumber),ERROR_MESSAGE());
    END CATCH;
    SET @LogNumber+=1;
END;

SELECT DISTINCT LogDate,ProcessInfo,[Text]
INTO #ErrorLogMatches
FROM #ErrorLogRaw
WHERE LogDate >= @Since AND LogDate <= @Now
  AND (
      UPPER([Text]) LIKE '%ERROR:%' OR
      UPPER([Text]) LIKE '%SEVERITY:%' OR
      UPPER([Text]) LIKE '%FAILED%' OR
      UPPER([Text]) LIKE '%CORRUPT%' OR
      UPPER([Text]) LIKE '%SUSPECT%' OR
      UPPER([Text]) LIKE '%I/O REQUEST%' OR
      UPPER([Text]) LIKE '%DEADLOCK%' OR
      UPPER([Text]) LIKE '%STACK DUMP%' OR
      UPPER([Text]) LIKE '%EXCEPTION%' OR
      UPPER([Text]) LIKE '%TIMEOUT%' OR
      UPPER([Text]) LIKE '%ASSERTION%' OR
      UPPER([Text]) LIKE '%INSUFFICIENT%' OR
      UPPER([Text]) LIKE '%OPERATING SYSTEM ERROR%'
  );

SELECT TOP (@ShowErrorLogRows) '02 ERRORLOG' AS Section,
       LogDate, ProcessInfo, [Text] AS Message
FROM #ErrorLogMatches
ORDER BY LogDate DESC;

IF EXISTS (SELECT 1 FROM #ErrorLogMatches)
    INSERT #Alerts
    SELECT CASE WHEN EXISTS
      (SELECT 1 FROM #ErrorLogMatches
       WHERE UPPER([Text]) LIKE '%CORRUPT%' OR UPPER([Text]) LIKE '%SUSPECT%'
          OR UPPER([Text]) LIKE '%ERROR: 823%' OR UPPER([Text]) LIKE '%ERROR: 824%'
          OR UPPER([Text]) LIKE '%ERROR: 825%' OR UPPER([Text]) LIKE '%STACK DUMP%'
          OR UPPER([Text]) LIKE '%ASSERTION%') THEN 'CRITICAL' ELSE 'WARNING' END,
      'ERRORLOG', 'SQL Server ERRORLOG',
      CONCAT('Matching log entries in last 24h: ',(SELECT COUNT_BIG(*) FROM #ErrorLogMatches),
             '; displayed newest ',@ShowErrorLogRows,
             '. Pattern matching is indicative; review the messages.') ;

/* 3. All SQL Server Agent jobs and recent failures */
BEGIN TRY
    ;WITH Activity AS
    (
      SELECT a.job_id,a.start_execution_date,a.stop_execution_date,
             ROW_NUMBER() OVER (PARTITION BY a.job_id ORDER BY a.session_id DESC) AS rn
      FROM msdb.dbo.sysjobactivity a
    )
    SELECT j.job_id, j.name AS JobName, j.enabled AS IsEnabled,
           CASE WHEN a.start_execution_date IS NOT NULL AND a.stop_execution_date IS NULL
                THEN 1 ELSE 0 END AS IsRunning,
           a.start_execution_date AS RunningSince,
           h.LastRunTime, h.run_status AS LastRunStatus, h.message AS LastMessage,
           CASE WHEN h.run_status=0 THEN 'FAILED'
                WHEN h.run_status=1 THEN 'SUCCEEDED'
                WHEN h.run_status=2 THEN 'RETRY'
                WHEN h.run_status=3 THEN 'CANCELED'
                WHEN h.run_status=4 THEN 'IN PROGRESS'
                ELSE 'NEVER RUN / NO HISTORY' END AS LastRunResult
    INTO #Jobs
    FROM msdb.dbo.sysjobs j
    LEFT JOIN Activity a ON a.job_id=j.job_id AND a.rn=1
    OUTER APPLY
    (
       SELECT TOP (1) h.run_status,h.message,
              CASE WHEN h.run_date > 0 AND h.run_time >= 0
                   THEN msdb.dbo.agent_datetime(h.run_date,h.run_time) END AS LastRunTime
       FROM msdb.dbo.sysjobhistory h
       WHERE h.job_id=j.job_id AND h.step_id=0
       ORDER BY h.instance_id DESC
    ) h;

    SELECT '03 JOBS - CURRENT' AS Section, JobName, IsEnabled, IsRunning,
           RunningSince,LastRunTime,LastRunResult,LastMessage
    FROM #Jobs
    ORDER BY CASE WHEN IsRunning=1 THEN 0 WHEN LastRunStatus IN (0,3) THEN 1
                  WHEN IsEnabled=0 THEN 2 ELSE 3 END, JobName;

    INSERT #Alerts
    SELECT 'CRITICAL','JOB',JobName,
           CONCAT('Last completed execution: ',LastRunResult,' at ',
                  COALESCE(CONVERT(varchar(19),LastRunTime,120),'unknown'))
    FROM #Jobs WHERE IsEnabled=1 AND IsRunning=0 AND LastRunStatus=0;

    INSERT #Alerts
    SELECT 'WARNING','JOB',JobName,
           CONCAT('Running since ',CONVERT(varchar(19),RunningSince,120))
    FROM #Jobs
    WHERE IsRunning=1 AND RunningSince < DATEADD(MINUTE,-@RunningJobWarningMinutes,@Now);

    SELECT '04 JOBS - FAILED/CANCELED LAST 24H' AS Section,
           j.name AS JobName,h.step_id,h.step_name,
           CASE h.run_status WHEN 0 THEN 'FAILED' WHEN 3 THEN 'CANCELED' ELSE 'OTHER' END AS Status,
           x.RunTime,h.sql_message_id,h.sql_severity,h.message
    INTO #RecentJobFailures
    FROM msdb.dbo.sysjobhistory h
    JOIN msdb.dbo.sysjobs j ON j.job_id=h.job_id
    CROSS APPLY (SELECT CASE WHEN h.run_date > 0
                            THEN msdb.dbo.agent_datetime(h.run_date,h.run_time) END AS RunTime) x
    WHERE h.run_status IN (0,3) AND x.RunTime >= @Since AND x.RunTime <= @Now;

    SELECT * FROM #RecentJobFailures ORDER BY RunTime DESC,JobName,step_id;

    INSERT #Alerts
    SELECT 'CRITICAL','JOB HISTORY',JobName,
           CONCAT('Failed/canceled job execution(s) in 24h: ',COUNT(*),
                  '; newest: ',CONVERT(varchar(19),MAX(RunTime),120))
    FROM #RecentJobFailures
    WHERE step_id=0 -- job outcomes; individual failed steps are visible in detail
    GROUP BY JobName;
END TRY
BEGIN CATCH
    INSERT #Alerts VALUES ('WARNING','JOBS',NULL,ERROR_MESSAGE());
END CATCH;

/* 4. Disks containing SQL data/log files -- NOT all OS volumes */
BEGIN TRY
    ;WITH Volumes AS
    (
      SELECT DISTINCT vs.volume_mount_point,vs.logical_volume_name,
             vs.total_bytes,vs.available_bytes
      FROM sys.master_files mf
      CROSS APPLY sys.dm_os_volume_stats(mf.database_id,mf.file_id) vs
      WHERE vs.total_bytes > 0
    )
    SELECT volume_mount_point,logical_volume_name,
           CAST(total_bytes / 1073741824.0 AS decimal(18,2)) AS TotalGB,
           CAST(available_bytes / 1073741824.0 AS decimal(18,2)) AS FreeGB,
           CAST(100.0*available_bytes / NULLIF(total_bytes,0) AS decimal(7,2)) AS FreePercent,
           total_bytes AS TotalBytes,available_bytes AS FreeBytes
    INTO #Volumes FROM Volumes;

    SELECT '05 DISK VOLUMES' AS Section,* FROM #Volumes ORDER BY FreePercent;

    INSERT #Alerts
    SELECT CASE WHEN FreePercent < @DiskCriticalPercent THEN 'CRITICAL' ELSE 'WARNING' END,
           'DISK',volume_mount_point,
           CONCAT('Free: ',FreeGB,' GB (',FreePercent,'%); total: ',TotalGB,' GB')
    FROM #Volumes WHERE FreePercent < @DiskWarningPercent;
END TRY
BEGIN CATCH
    INSERT #Alerts VALUES ('WARNING','DISK',NULL,ERROR_MESSAGE());
END CATCH;

/* 5. Databases and backup history. No blanket policy for DIFF; user can inspect latest. */
BEGIN TRY
    SELECT d.name AS DatabaseName,d.state_desc,d.recovery_model_desc,
           d.is_read_only,d.is_in_standby,
           bFull.backup_finish_date AS LastFull,
           bDiff.backup_finish_date AS LastDiff,
           bLog.backup_finish_date AS LastLog
    INTO #Databases
    FROM sys.databases d
    OUTER APPLY
    (
      SELECT MAX(backup_finish_date) AS backup_finish_date
      FROM msdb.dbo.backupset b WHERE b.database_name=d.name AND b.type='D'
    ) bFull
    OUTER APPLY
    (
      SELECT MAX(backup_finish_date) AS backup_finish_date
      FROM msdb.dbo.backupset b WHERE b.database_name=d.name AND b.type='I'
    ) bDiff
    OUTER APPLY
    (
      SELECT MAX(backup_finish_date) AS backup_finish_date
      FROM msdb.dbo.backupset b WHERE b.database_name=d.name AND b.type='L'
    ) bLog
    WHERE d.source_database_id IS NULL; -- exclude snapshots

    SELECT '06 DATABASES + BACKUPS' AS Section,* FROM #Databases
    ORDER BY CASE WHEN state_desc<>'ONLINE' THEN 0 ELSE 1 END,DatabaseName;

    INSERT #Alerts
    SELECT 'CRITICAL','DATABASE',DatabaseName,CONCAT('Database state: ',state_desc)
    FROM #Databases WHERE state_desc<>'ONLINE' AND DatabaseName<>'tempdb';

    INSERT #Alerts
    SELECT 'WARNING','BACKUP FULL',DatabaseName,
           CONCAT('Last FULL: ',COALESCE(CONVERT(varchar(19),LastFull,120),'NOT FOUND IN MSDB'))
    FROM #Databases
    WHERE DatabaseName NOT IN ('tempdb','model') AND state_desc='ONLINE'
      AND is_read_only=0 AND (LastFull IS NULL OR LastFull<DATEADD(HOUR,-@FullBackupMaxHours,@Now));

    INSERT #Alerts
    SELECT 'WARNING','BACKUP LOG',DatabaseName,
           CONCAT('Last LOG: ',COALESCE(CONVERT(varchar(19),LastLog,120),'NOT FOUND IN MSDB'))
    FROM #Databases
    WHERE DatabaseName NOT IN ('master','model','msdb','tempdb')
      AND state_desc='ONLINE' AND is_read_only=0
      AND recovery_model_desc IN ('FULL','BULK_LOGGED')
      AND (LastLog IS NULL OR LastLog<DATEADD(MINUTE,-@LogBackupMaxMinutes,@Now));
END TRY
BEGIN CATCH
    INSERT #Alerts VALUES ('WARNING','BACKUP/DB',NULL,ERROR_MESSAGE());
END CATCH;

/* 6. Transaction log usage -- DBCC SQLPERF(LOGSPACE) is observational */
BEGIN TRY
    CREATE TABLE #LogSpace
    (
       DatabaseName sysname, LogSizeMB float, LogSpaceUsedPercent float, [Status] int
    );
    INSERT #LogSpace EXEC ('DBCC SQLPERF(LOGSPACE) WITH NO_INFOMSGS');

    SELECT '07 TRANSACTION LOG' AS Section,DatabaseName,
           CAST(LogSizeMB AS decimal(19,2)) AS LogSizeMB,
           CAST(LogSpaceUsedPercent AS decimal(7,2)) AS UsedPercent
    FROM #LogSpace ORDER BY LogSpaceUsedPercent DESC;

    INSERT #Alerts
    SELECT CASE WHEN LogSpaceUsedPercent>=@LogCriticalPercent THEN 'CRITICAL' ELSE 'WARNING' END,
           'TRANSACTION LOG',DatabaseName,
           CONCAT('Log used: ',CAST(LogSpaceUsedPercent AS decimal(7,2)),
                  '%; size ',CAST(LogSizeMB AS decimal(19,2)),' MB')
    FROM #LogSpace WHERE LogSpaceUsedPercent>=@LogWarningPercent;
END TRY
BEGIN CATCH
    INSERT #Alerts VALUES ('WARNING','TRANSACTION LOG',NULL,ERROR_MESSAGE());
END CATCH;

/* 7. Current blocking, not historical blocking */
BEGIN TRY
    SELECT r.session_id AS BlockedSessionId,r.blocking_session_id AS BlockerSessionId,
           DB_NAME(r.database_id) AS DatabaseName,r.wait_type,
           CAST(r.wait_time/1000.0 AS decimal(15,1)) AS WaitSeconds,
           r.status,s.host_name,s.program_name,s.login_name,
           SUBSTRING(t.text, (r.statement_start_offset/2)+1,
                    ((CASE WHEN r.statement_end_offset=-1
                           THEN DATALENGTH(t.text)
                           ELSE r.statement_end_offset END-r.statement_start_offset)/2)+1)
           AS RunningStatement
    INTO #Blocking
    FROM sys.dm_exec_requests r
    JOIN sys.dm_exec_sessions s ON s.session_id=r.session_id
    OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE r.blocking_session_id<>0 AND r.session_id<>@@SPID;

    SELECT '08 CURRENT BLOCKING' AS Section,* FROM #Blocking ORDER BY WaitSeconds DESC;

    INSERT #Alerts
    SELECT 'WARNING','BLOCKING',CONCAT('SPID ',BlockedSessionId),
           CONCAT('Blocked by SPID ',BlockerSessionId,' for ',WaitSeconds,
                  ' s; wait ',COALESCE(wait_type,'unknown'))
    FROM #Blocking WHERE WaitSeconds>=@BlockingWarningSeconds;
END TRY
BEGIN CATCH
    INSERT #Alerts VALUES ('WARNING','BLOCKING',NULL,ERROR_MESSAGE());
END CATCH;

/* 8. File configuration and current allocations (always available, read-only) */
BEGIN TRY
    SELECT mf.database_id,mf.file_id,DB_NAME(mf.database_id) AS DatabaseName,
           mf.name AS LogicalFileName,mf.physical_name AS PhysicalName,mf.type_desc,
           CONVERT(bigint,mf.size) AS SizePages,
           CONVERT(decimal(19,2),mf.size/128.0) AS AllocatedMB,
           mf.growth,mf.is_percent_growth,mf.max_size,
           CASE WHEN mf.growth=0 THEN 'DISABLED'
                WHEN mf.is_percent_growth=1 THEN CONCAT(mf.growth,'%')
                ELSE CONCAT(CONVERT(decimal(19,2),mf.growth/128.0),' MB') END AS GrowthSetting,
           CASE WHEN mf.max_size=-1 THEN 'UNLIMITED'
                WHEN mf.max_size=0 THEN 'NO GROWTH'
                ELSE CONCAT(CONVERT(decimal(19,2),mf.max_size/128.0),' MB') END AS MaxSizeSetting
    INTO #CurrentFiles
    FROM sys.master_files mf;

    SELECT '09 FILES - SIZE AND AUTOGROWTH' AS Section,DatabaseName,LogicalFileName,
           type_desc,AllocatedMB,GrowthSetting,MaxSizeSetting,PhysicalName
    FROM #CurrentFiles ORDER BY DatabaseName,LogicalFileName;

    INSERT #Alerts
    SELECT 'WARNING','FILE CONFIG',DatabaseName + N'.' + LogicalFileName,
           CONCAT('Percentage autogrowth configured: ',GrowthSetting,'; size ',AllocatedMB,' MB')
    FROM #CurrentFiles WHERE is_percent_growth=1 AND growth>0;

    INSERT #Alerts
    SELECT 'WARNING','FILE CONFIG',DatabaseName + N'.' + LogicalFileName,
           CONCAT('Autogrowth disabled; allocated ',AllocatedMB,' MB')
    FROM #CurrentFiles WHERE growth=0 AND max_size<>0 AND database_id<>2;
END TRY
BEGIN CATCH
    INSERT #Alerts VALUES ('WARNING','FILES',NULL,ERROR_MESSAGE());
END CATCH;

/* 9. Expected SQL Agent schedule occurrences within the last 24 hours.
   Covers one-time, daily, weekly and monthly absolute schedules.
   Sub-day intervals of >=60 seconds; startup/idle and <60s schedules are listed
   as unsupported for inference. This is a heuristic, not an Agent scheduler audit.
*/
BEGIN TRY
    CREATE TABLE #ScheduleCoverage(JobName sysname,ScheduleName sysname,Reason nvarchar(180));
    SELECT j.job_id,j.name AS JobName,s.schedule_id,s.name AS ScheduleName,
           s.freq_type,s.freq_interval,s.freq_subday_type,s.freq_subday_interval,
           s.freq_relative_interval,s.freq_recurrence_factor,
           s.active_start_date,s.active_end_date,s.active_start_time,s.active_end_time,
           s.enabled AS ScheduleEnabled,j.enabled AS JobEnabled
    INTO #ActiveSchedules
    FROM msdb.dbo.sysjobs j
    JOIN msdb.dbo.sysjobschedules js ON js.job_id=j.job_id
    JOIN msdb.dbo.sysschedules s ON s.schedule_id=js.schedule_id
    WHERE j.enabled=1 AND s.enabled=1;

    INSERT #ScheduleCoverage
    SELECT JobName,ScheduleName,
           CASE WHEN freq_type IN (64,128) THEN 'Startup/idle trigger (not time-based)'
                WHEN freq_type=32 THEN 'Monthly relative schedule: not evaluated (avoid false positives)'
                WHEN freq_type NOT IN (1,4,8,16) THEN 'Unsupported frequency type'
                WHEN freq_subday_type=2 AND freq_subday_interval<60 THEN 'Interval shorter than 60 seconds'
                WHEN freq_subday_type NOT IN (1,2,4,8) THEN 'Unsupported subday interval'
                WHEN freq_subday_interval<=0 AND freq_subday_type<>1 THEN 'Invalid subday interval'
                ELSE 'Unsupported calendar configuration' END
    FROM #ActiveSchedules
    WHERE freq_type NOT IN (1,4,8,16)
       OR freq_subday_type NOT IN (1,2,4,8)
       OR (freq_subday_type=2 AND freq_subday_interval<60)
       OR (freq_subday_type<>1 AND freq_subday_interval<=0);

    /* 0..1439 slots; one date + one previous day sufficient for 24h local period. */
    ;WITH N AS
    (
      SELECT TOP (1440) ROW_NUMBER() OVER(ORDER BY (SELECT NULL))-1 AS n
      FROM sys.all_objects a CROSS JOIN sys.all_objects b
    )
    SELECT n INTO #MinuteSlots FROM N;

    SELECT x.JobName,x.ScheduleName,x.job_id,x.schedule_id,x.ExpectedAt
    INTO #ExpectedRuns
    FROM #ActiveSchedules s
    CROSS JOIN (VALUES (CONVERT(date,@Now)),(DATEADD(day,-1,CONVERT(date,@Now)))) v(RunDay)
    CROSS JOIN #MinuteSlots n
    CROSS APPLY
    (
      SELECT CONVERT(date,CONVERT(char(8),s.active_start_date),112) AS StartDay,
             CONVERT(date,CONVERT(char(8),s.active_end_date),112) AS EndDay,
             DATEADD(SECOND,
               (s.active_start_time/10000)*3600 + ((s.active_start_time/100)%100)*60 + s.active_start_time%100,
               CONVERT(datetime2(0),v.RunDay)) AS DayStart,
             (s.active_end_time/10000)*3600 + ((s.active_end_time/100)%100)*60 + s.active_end_time%100 AS EndSecond,
             ((DATEDIFF(day,CONVERT(date,'19000107'),v.RunDay)%7+7)%7) AS SundayBasedWeekday,
             DATEDIFF(month,CONVERT(date,CONVERT(char(8),s.active_start_date),112),v.RunDay) AS MonthsElapsed
    ) d
    CROSS APPLY
    (
      SELECT DATEADD(SECOND,
        CASE s.freq_subday_type WHEN 1 THEN 0
             WHEN 2 THEN n.n*s.freq_subday_interval
             WHEN 4 THEN n.n*s.freq_subday_interval*60
             WHEN 8 THEN n.n*s.freq_subday_interval*3600 END,
        d.DayStart) AS ExpectedAt,
        s.JobName,s.ScheduleName,s.job_id,s.schedule_id
    ) x
    WHERE s.freq_type IN (1,4,8,16)
      AND s.freq_subday_type IN (1,2,4,8)
      AND (s.freq_subday_type=1 OR (s.freq_subday_interval>0 AND
                      (s.freq_subday_type<>2 OR s.freq_subday_interval>=60)))
      AND (s.freq_subday_type<>1 OR n.n=0)
      AND v.RunDay BETWEEN d.StartDay AND d.EndDay
      AND x.ExpectedAt BETWEEN @Since AND DATEADD(MINUTE,-@MissingJobGraceMinutes,@Now)
      AND DATEDIFF(SECOND,CONVERT(datetime2(0),v.RunDay),x.ExpectedAt)<=d.EndSecond
      AND (
          (s.freq_type=1 AND v.RunDay=d.StartDay)
          OR (s.freq_type=4 AND DATEDIFF(day,d.StartDay,v.RunDay)%NULLIF(s.freq_interval,0)=0)
          OR (s.freq_type=8 AND
                 (s.freq_interval & CONVERT(int,POWER(CONVERT(float,2),d.SundayBasedWeekday)))<>0
                 AND (DATEDIFF(day,
                       DATEADD(day,-(((DATEDIFF(day,CONVERT(date,'19000107'),d.StartDay)%7+7)%7)),d.StartDay),
                       DATEADD(day,-d.SundayBasedWeekday,v.RunDay))/7)
                      % NULLIF(s.freq_recurrence_factor,0)=0)
          OR (s.freq_type=16 AND d.MonthsElapsed%NULLIF(s.freq_recurrence_factor,0)=0
                 AND DAY(v.RunDay)=s.freq_interval)

      );

    /* Treat a scheduled slot as covered by any full job outcome that started
       close to the expected time, or by the job currently running. */
    SELECT e.JobName,e.ScheduleName,e.ExpectedAt
    INTO #MissedRuns
    FROM #ExpectedRuns e
    WHERE NOT EXISTS
    (
      SELECT 1 FROM msdb.dbo.sysjobhistory h
      WHERE h.job_id=e.job_id AND h.step_id=0 AND h.run_date>0
        AND msdb.dbo.agent_datetime(h.run_date,h.run_time)
            BETWEEN DATEADD(MINUTE,-@JobStartToleranceMinutes,e.ExpectedAt)
                AND DATEADD(MINUTE,@JobStartToleranceMinutes,e.ExpectedAt)
    )
    AND NOT EXISTS
    (
      SELECT 1 FROM #Jobs j
      WHERE j.job_id=e.job_id AND j.IsRunning=1
    )
    AND NOT EXISTS
    (
      SELECT 1 FROM msdb.dbo.sysjobhistory h
      CROSS APPLY (SELECT msdb.dbo.agent_datetime(h.run_date,h.run_time) AS StartedAt) t
      WHERE h.job_id=e.job_id AND h.step_id=0 AND h.run_date>0
        AND t.StartedAt<e.ExpectedAt
        AND DATEADD(SECOND,
             (h.run_duration/10000)*3600+((h.run_duration/100)%100)*60+h.run_duration%100,
             t.StartedAt) >=e.ExpectedAt
    );

    SELECT '10 SCHEDULED JOBS - POSSIBLY MISSED' AS Section,*
    FROM #MissedRuns ORDER BY ExpectedAt DESC,JobName;

    SELECT '10B SCHEDULES - NOT EVALUATED' AS Section,*
    FROM #ScheduleCoverage ORDER BY JobName,ScheduleName;

    INSERT #Alerts
    SELECT 'WARNING','MISSED JOB',JobName,
           CONCAT('Potentially missed scheduled starts: ',COUNT(*),
                  '; latest ',CONVERT(varchar(19),MAX(ExpectedAt),120),
                  '. Check Agent availability, overlaps and schedule changes.')
    FROM #MissedRuns GROUP BY JobName;
END TRY
BEGIN CATCH
    INSERT #Alerts VALUES ('WARNING','JOB SCHEDULE',NULL,ERROR_MESSAGE());
END CATCH;

/* 10. Change history: previous sample, then optional save. */
BEGIN TRY
    IF OBJECT_ID(N'SQLManiakHealthHistory.hc.Sample',N'U') IS NULL
    BEGIN
        SELECT '11 HISTORY' AS Section,
               'History database not installed; file/disk trends and FCI owner changes unavailable' AS Message;
        INSERT #Alerts VALUES ('INFO','HISTORY',NULL,
             'Run SQLManiak_HealthHistory_Setup.sql once to enable historical comparisons.');
    END
    ELSE
    BEGIN
        DECLARE @InstanceName nvarchar(128) = CONVERT(nvarchar(128),SERVERPROPERTY('ServerName'));
        DECLARE @Node nvarchar(128) = CONVERT(nvarchar(128),SERVERPROPERTY('ComputerNamePhysicalNetBIOS'));
        DECLARE @IsClustered bit = CONVERT(bit,SERVERPROPERTY('IsClustered'));
        DECLARE @PreviousSampleId bigint,@PreviousAt datetime2(0),@PreviousNode nvarchar(128),@CurrentSampleId bigint;
        SELECT TOP (1) @PreviousSampleId=SampleId,@PreviousAt=CapturedAt,@PreviousNode=ActiveNode
        FROM SQLManiakHealthHistory.hc.Sample
        WHERE InstanceName=@InstanceName
        ORDER BY CapturedAt DESC,SampleId DESC;

        IF @IsClustered=1 AND @PreviousSampleId IS NOT NULL AND
           ISNULL(@Node,N'')<>ISNULL(@PreviousNode,N'')
            INSERT #Alerts VALUES ('WARNING','FCI FAILOVER',@InstanceName,
               CONCAT('Active node changed: ',COALESCE(@PreviousNode,'(unknown)'),
                      ' -> ',COALESCE(@Node,'(unknown)'),
                      '; prior sample ',CONVERT(varchar(19),@PreviousAt,120)));

        SELECT f.DatabaseName,f.LogicalFileName,f.type_desc,f.AllocatedMB AS CurrentMB,
               CONVERT(decimal(19,2),p.SizePages/128.0) AS PreviousMB,
               CONVERT(decimal(19,2),(f.SizePages-p.SizePages)/128.0) AS ChangeMB,
               @PreviousAt AS PreviousCapturedAt
        INTO #FileChanges
        FROM #CurrentFiles f
        LEFT JOIN SQLManiakHealthHistory.hc.FileSample p
          ON p.SampleId=@PreviousSampleId AND p.DatabaseId=f.database_id AND p.FileId=f.file_id
          AND p.PhysicalName=f.PhysicalName;

        SELECT '11 FILE GROWTH SINCE PRIOR SAMPLE' AS Section,*
        FROM #FileChanges ORDER BY ChangeMB DESC,DatabaseName;

        INSERT #Alerts
        SELECT 'WARNING','FILE GROWTH',DatabaseName + N'.' + LogicalFileName,
               CONCAT('Net allocated size increase: ',ChangeMB,' MB since ',
                      CONVERT(varchar(19),@PreviousAt,120))
        FROM #FileChanges WHERE ChangeMB>=@FileGrowthWarningGB*1024;

        SELECT v.volume_mount_point,v.TotalGB,v.FreeGB,v.FreePercent,
               CONVERT(decimal(19,2),p.FreeBytes/1073741824.0) AS PreviousFreeGB,
               CONVERT(decimal(19,2),(v.FreeBytes-p.FreeBytes)/1073741824.0) AS ChangeFreeGB,
               CASE WHEN DATEDIFF(MINUTE,@PreviousAt,@Now)>=60
                    THEN CONVERT(decimal(19,2),
                        (p.FreeBytes-v.FreeBytes)/1073741824.0*1440.0/
                        NULLIF(DATEDIFF(MINUTE,@PreviousAt,@Now),0)) END AS ConsumptionGBPerDay,
               @PreviousAt AS PreviousCapturedAt
        INTO #DiskTrend
        FROM #Volumes v
        LEFT JOIN SQLManiakHealthHistory.hc.VolumeSample p
          ON p.SampleId=@PreviousSampleId AND p.VolumeMountPoint=v.volume_mount_point;

        SELECT '12 DISK TREND SINCE PRIOR SAMPLE' AS Section,*
        FROM #DiskTrend ORDER BY ConsumptionGBPerDay DESC;

        INSERT #Alerts
        SELECT 'WARNING','DISK TREND',volume_mount_point,
               CONCAT('Estimated disk free-space decline: ',ConsumptionGBPerDay,
                      ' GB/day over sample interval; previous sample ',
                      CONVERT(varchar(19),@PreviousAt,120))
        FROM #DiskTrend WHERE ConsumptionGBPerDay>=@DiskDeclineWarningGBPerDay;

        IF @SaveHistory=1
        BEGIN
            BEGIN TRANSACTION;
            INSERT SQLManiakHealthHistory.hc.Sample(CapturedAt,InstanceName,IsClustered,ActiveNode)
            VALUES (@Now,@InstanceName,@IsClustered,@Node);
            SET @CurrentSampleId=SCOPE_IDENTITY();
            INSERT SQLManiakHealthHistory.hc.VolumeSample(SampleId,VolumeMountPoint,TotalBytes,FreeBytes)
            SELECT @CurrentSampleId,volume_mount_point,
                   TotalBytes,FreeBytes
            FROM #Volumes;
            INSERT SQLManiakHealthHistory.hc.FileSample
                (SampleId,DatabaseId,FileId,DatabaseName,LogicalFileName,PhysicalName,
                 TypeDesc,SizePages,Growth,IsPercentGrowth,MaxSize)
            SELECT @CurrentSampleId,database_id,file_id,DatabaseName,LogicalFileName,PhysicalName,
                   type_desc,SizePages,growth,is_percent_growth,max_size
            FROM #CurrentFiles;
            COMMIT TRANSACTION;
        END;
        SELECT '12B FCI ACTIVE NODE' AS Section,@InstanceName AS InstanceName,
               @IsClustered AS IsClustered,@PreviousNode AS PreviousNode,
               @Node AS CurrentNode,@PreviousAt AS PreviousCapturedAt,
               @CurrentSampleId AS SavedSampleId;
    END;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    INSERT #Alerts VALUES ('WARNING','HISTORY',NULL,ERROR_MESSAGE());
END CATCH;


/* 12C. ACTUAL AUTOGROWTH EVENTS - read-only, default trace (92=data,93=log).
   This is not the same as net growth between file snapshots.
   Default Trace is a rolling/finite history; zero events is not proof of none.
   The section intentionally returns one row for EVERY current ROWS/LOG file.
   No XEvent session is created and no server settings are changed.
*/
BEGIN TRY
    DECLARE @AutoGrowthTracePath nvarchar(260) = NULL;
    DECLARE @AutoGrowthHistoryStatus varchar(32) = 'UNAVAILABLE';

    SELECT TOP (1) @AutoGrowthTracePath = [path]
    FROM sys.traces WHERE is_default = 1;

    -- Default Trace FileName contains the LOGICAL file name.
    CREATE TABLE #AutoGrowthEvents
    (
        DatabaseID int NULL,
        LogicalFileName nvarchar(260) COLLATE DATABASE_DEFAULT NULL,
        StartTime datetime NULL,
        EventClass int NOT NULL,
        GrowthMB decimal(19,2) NULL,
        DurationMs decimal(19,2) NULL
    );

    IF @AutoGrowthTracePath IS NOT NULL
    BEGIN
        BEGIN TRY
            INSERT #AutoGrowthEvents(DatabaseID,LogicalFileName,StartTime,EventClass,GrowthMB,DurationMs)
            SELECT t.DatabaseID,t.FileName,t.StartTime,t.EventClass,
                   CONVERT(decimal(19,2),CONVERT(float,t.IntegerData) / 128.0),
                   CONVERT(decimal(19,2),CONVERT(float,t.Duration) / 1000.0)
            FROM sys.fn_trace_gettable(@AutoGrowthTracePath,DEFAULT) AS t
            WHERE t.EventClass IN (92,93) AND t.StartTime IS NOT NULL;
            SET @AutoGrowthHistoryStatus = 'AVAILABLE_PARTIAL';
        END TRY
        BEGIN CATCH
            INSERT #Alerts VALUES ('WARNING','AUTOGROWTH',NULL,
                CONCAT('Cannot read Default Trace: ',ERROR_MESSAGE()));
        END CATCH;
    END
    ELSE
        INSERT #Alerts VALUES ('WARNING','AUTOGROWTH',NULL,
            'Default Trace unavailable: actual autogrowth events cannot be verified.');

    ;WITH EventAgg AS
    (
        SELECT DatabaseID,LogicalFileName,
               COUNT_BIG(*) AS EventsInAvailableTrace,
               SUM(CASE WHEN StartTime >= @Since AND StartTime <= @Now THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS Events24h,
               MAX(StartTime) AS LastAutoGrowth,
               SUM(CASE WHEN StartTime >= @Since AND StartTime <= @Now THEN GrowthMB ELSE CONVERT(decimal(19,2),0) END) AS GrowthMB24h,
               MAX(CASE WHEN StartTime >= @Since AND StartTime <= @Now THEN DurationMs END) AS MaxDurationMs24h
        FROM #AutoGrowthEvents
        GROUP BY DatabaseID,LogicalFileName
    )
    SELECT f.database_id,f.file_id,f.DatabaseName,f.LogicalFileName,f.type_desc AS FileType,
           f.PhysicalName,f.AllocatedMB,f.GrowthSetting,
           @AutoGrowthHistoryStatus AS HistoryStatus,
           CASE WHEN @AutoGrowthHistoryStatus <> 'AVAILABLE_PARTIAL' THEN NULL
                ELSE ISNULL(a.Events24h,CONVERT(bigint,0)) END AS Events24h,
           CASE WHEN @AutoGrowthHistoryStatus <> 'AVAILABLE_PARTIAL' THEN NULL
                ELSE ISNULL(a.GrowthMB24h,CONVERT(decimal(19,2),0)) END AS GrowthMB24h,
           CASE WHEN @AutoGrowthHistoryStatus <> 'AVAILABLE_PARTIAL' THEN NULL
                ELSE a.LastAutoGrowth END AS LastAutoGrowth,
           CASE WHEN @AutoGrowthHistoryStatus <> 'AVAILABLE_PARTIAL' THEN NULL
                ELSE a.MaxDurationMs24h END AS MaxDurationMs24h,
           CASE WHEN @AutoGrowthHistoryStatus <> 'AVAILABLE_PARTIAL' THEN NULL
                ELSE ISNULL(a.EventsInAvailableTrace,CONVERT(bigint,0)) END AS EventsInAvailableTrace
    INTO #AutoGrowthReport
    FROM #CurrentFiles AS f
    LEFT JOIN EventAgg AS a
      ON a.DatabaseID = f.database_id
     AND a.LogicalFileName = f.LogicalFileName COLLATE DATABASE_DEFAULT
    WHERE f.type_desc IN ('ROWS','LOG');

    SELECT '12C AUTOGROWTH EVENTS' AS Section,
           DatabaseName,LogicalFileName,FileType,AllocatedMB,GrowthSetting,
           HistoryStatus,Events24h,GrowthMB24h,LastAutoGrowth,MaxDurationMs24h,
           EventsInAvailableTrace,PhysicalName
    FROM #AutoGrowthReport
    ORDER BY Events24h DESC,DatabaseName,LogicalFileName;

    INSERT #Alerts(Severity,Area,ObjectName,Details)
    SELECT CASE WHEN Events24h >= @AutoGrowthFrequentCount * 3 THEN 'CRITICAL' ELSE 'WARNING' END,
           'AUTOGROWTH',CONCAT(DatabaseName,'.',LogicalFileName),
           CONCAT('Frequent autogrowth: ',Events24h,' events in available 24h; ',
                  GrowthMB24h,' MB total; longest ',COALESCE(CONVERT(varchar(40),MaxDurationMs24h),'n/a'),' ms')
    FROM #AutoGrowthReport
    WHERE Events24h >= @AutoGrowthFrequentCount;

    INSERT #Alerts(Severity,Area,ObjectName,Details)
    SELECT 'WARNING','AUTOGROWTH',CONCAT(DatabaseName,'.',LogicalFileName),
           CONCAT('Slow autogrowth: maximum ',MaxDurationMs24h,
                  ' ms in available 24h; events: ',Events24h)
    FROM #AutoGrowthReport
    WHERE MaxDurationMs24h >= @AutoGrowthSlowMs
      AND (Events24h < @AutoGrowthFrequentCount OR Events24h IS NULL);

    INSERT #Alerts(Severity,Area,ObjectName,Details)
    SELECT 'WARNING','AUTOGROWTH',CONCAT(DatabaseName,'.',LogicalFileName),
           CONCAT('High autogrowth volume: ',GrowthMB24h,
                  ' MB in available 24h; events: ',Events24h)
    FROM #AutoGrowthReport
    WHERE GrowthMB24h >= @AutoGrowthGrowthWarningMB
      AND (Events24h < @AutoGrowthFrequentCount OR Events24h IS NULL)
      AND (MaxDurationMs24h < @AutoGrowthSlowMs OR MaxDurationMs24h IS NULL);
END TRY
BEGIN CATCH
    INSERT #Alerts VALUES ('WARNING','AUTOGROWTH',NULL,
        CONCAT('Autogrowth audit failed: ',ERROR_MESSAGE()));
END CATCH;

/* 12D. LOG OVERSIZING ANALYSIS -- READ ONLY, no shrink, no file changes.
   DBCC SQLPERF(LOGSPACE) reports used LOG for all databases at this instant.
   VLF diagnostics are best effort; privileges may restrict sys.dm_db_log_info.
   A large, mostly unused LOG is a review candidate, NOT automatic evidence
   that shrinking is safe. Daily restores can recreate source file sizes.
*/
BEGIN TRY
    CREATE TABLE #LogSpaceAudit
    (
        DatabaseName sysname COLLATE DATABASE_DEFAULT NOT NULL,
        LogSizeMB float NULL,
        LogSpaceUsedPercent float NULL,
        [Status] int NULL
    );

    INSERT #LogSpaceAudit(DatabaseName,LogSizeMB,LogSpaceUsedPercent,[Status])
    EXEC ('DBCC SQLPERF(LOGSPACE) WITH NO_INFOMSGS');

    ;WITH FileTotals AS
    (
        SELECT database_id,
               SUM(CASE WHEN [type] = 0 THEN CONVERT(bigint,[size]) ELSE CONVERT(bigint,0) END) / 128.0 AS DataSizeMB,
               SUM(CASE WHEN [type] = 1 THEN CONVERT(bigint,[size]) ELSE CONVERT(bigint,0) END) / 128.0 AS LogSizeMB
        FROM sys.master_files
        GROUP BY database_id
    )
    SELECT d.database_id,
           d.name AS DatabaseName,
           d.recovery_model_desc AS RecoveryModel,
           d.log_reuse_wait_desc AS LogReuseWait,
           CONVERT(decimal(19,2),f.DataSizeMB / 1024.0) AS DataSizeGB,
           CONVERT(decimal(19,2),f.LogSizeMB / 1024.0) AS LogSizeGB,
           CONVERT(decimal(19,2),f.LogSizeMB / NULLIF(f.DataSizeMB,0)) AS LogToDataRatio,
           CONVERT(decimal(9,2),l.LogSpaceUsedPercent) AS LogUsedPercent,
           CONVERT(decimal(19,2),l.LogSizeMB * l.LogSpaceUsedPercent / 100.0) AS UsedLogMB,
           CONVERT(decimal(19,2),l.LogSizeMB * (100.0 - l.LogSpaceUsedPercent) / 100.0) AS FreeLogMB,
           CONVERT(int,NULL) AS TotalVLF,
           CONVERT(int,NULL) AS ActiveVLF,
           CONVERT(decimal(19,2),NULL) AS ActiveVLFSizeMB,
           CONVERT(varchar(32),'NOT_CHECKED') AS VLFStatus
    INTO #LogOversize
    FROM sys.databases AS d
    INNER JOIN FileTotals AS f ON d.database_id = f.database_id
    INNER JOIN #LogSpaceAudit AS l ON l.DatabaseName = d.name COLLATE DATABASE_DEFAULT
    WHERE d.state = 0
      AND f.LogSizeMB > 0
      AND (f.LogSizeMB > f.DataSizeMB OR
           (f.LogSizeMB >= @LogOversizeMinGB * 1024.0 AND l.LogSpaceUsedPercent <= @LogOversizeMaxUsedPercent));

    -- VLF enumeration restricted to selected candidates (rather than every database).
    DECLARE @VlfDbId int;
    DECLARE vlf_candidates CURSOR LOCAL FAST_FORWARD FOR
        SELECT database_id FROM #LogOversize ORDER BY database_id;
    OPEN vlf_candidates;
    FETCH NEXT FROM vlf_candidates INTO @VlfDbId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            UPDATE r
               SET TotalVLF = x.TotalVLF,
                   ActiveVLF = x.ActiveVLF,
                   ActiveVLFSizeMB = x.ActiveVLFSizeMB,
                   VLFStatus = 'OK'
            FROM #LogOversize AS r
            CROSS APPLY
            (
                SELECT COUNT(*) AS TotalVLF,
                       SUM(CASE WHEN vlf_active = 1 THEN 1 ELSE 0 END) AS ActiveVLF,
                       CONVERT(decimal(19,2),SUM(CASE WHEN vlf_active = 1 THEN vlf_size_mb ELSE 0 END)) AS ActiveVLFSizeMB
                FROM sys.dm_db_log_info(@VlfDbId)
            ) AS x
            WHERE r.database_id = @VlfDbId;
        END TRY
        BEGIN CATCH
            UPDATE #LogOversize SET VLFStatus = 'UNAVAILABLE' WHERE database_id = @VlfDbId;
        END CATCH;
        FETCH NEXT FROM vlf_candidates INTO @VlfDbId;
    END;
    CLOSE vlf_candidates;
    DEALLOCATE vlf_candidates;

    SELECT '12D LOG OVERSIZING' AS Section,
           DatabaseName,RecoveryModel,DataSizeGB,LogSizeGB,LogToDataRatio,
           LogUsedPercent,UsedLogMB,FreeLogMB,LogReuseWait,
           TotalVLF,ActiveVLF,ActiveVLFSizeMB,VLFStatus,
           CASE WHEN LogSizeGB >= @LogOversizeMinGB
                     AND LogToDataRatio > @LogOversizeMinRatio
                     AND LogUsedPercent <= @LogOversizeMaxUsedPercent
                THEN 'REVIEW - OVERSIZED LOG'
                ELSE 'INFO' END AS Assessment
    FROM #LogOversize
    ORDER BY LogSizeGB DESC,DatabaseName;

    INSERT #Alerts(Severity,Area,ObjectName,Details)
    SELECT 'WARNING','LOG OVERSIZING',DatabaseName,
           CONCAT('LOG ',LogSizeGB,' GB vs DATA ',DataSizeGB,
                  ' GB; used ',LogUsedPercent,'%; free ~',FreeLogMB,
                  ' MB; reuse wait ',LogReuseWait,
                  '. Review workload and next RESTORE; no automatic SHRINK.')
    FROM #LogOversize
    WHERE LogSizeGB >= @LogOversizeMinGB
      AND LogToDataRatio > @LogOversizeMinRatio
      AND LogUsedPercent <= @LogOversizeMaxUsedPercent;
END TRY
BEGIN CATCH
    INSERT #Alerts VALUES ('WARNING','LOG OVERSIZING',NULL,
        CONCAT('LOG oversizing audit unavailable: ',ERROR_MESSAGE()));
END CATCH;

/* 11. Actionable summary */
SELECT '13 SUMMARY' AS Section, Severity,Area,ObjectName,Details
FROM #Alerts
ORDER BY CASE Severity WHEN 'CRITICAL' THEN 1 WHEN 'WARNING' THEN 2 ELSE 3 END,
         Area,ObjectName,Id;

SELECT '14 COUNTS' AS Section,
       (SELECT COUNT(*) FROM #Alerts WHERE Severity='CRITICAL') AS CriticalAlerts,
       (SELECT COUNT(*) FROM #Alerts WHERE Severity='WARNING') AS WarningAlerts,
       (SELECT COUNT(*) FROM #Alerts WHERE Severity='INFO') AS InfoAlerts,
       @Since AS SinceTime,@Now AS UntilTime;

/* Notes:
 - Expected schedule detection is a best-effort approximation, not Agent internals.
   Agent downtime, schedule editing, daylight savings and overlapping jobs can
   produce false positives. Startup/idle and <60-second schedules excluded.
 - Growth between snapshots is NET change, not proof of an autogrowth event.
 - Autogrowth event history uses Default Trace; its rolling retention may be less than 24 hours.
 - No Extended Events session is deployed by this diagnostic script.
 - LOG oversizing analysis is read-only; low utilisation does not justify automatic SHRINK.
 - Disk trend uses last two runs; run daily at similar time for interpretation.
 - FCI comparison detects active-node changes between snapshots, not every failover.
 - A history write is the only modification made by the daily script.
*/
