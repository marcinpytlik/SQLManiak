
/* Generate_AgentJobs_2016.sql */
USE msdb;
SET NOCOUNT ON;

-- 1) Jobs header
SELECT
    '-- Job: ' + QUOTENAME(j.name) + CHAR(10) +
    'IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N' + QUOTENAME(j.name,'''') + ')'+CHAR(10)+
    'BEGIN'+CHAR(10)+
    '    EXEC msdb.dbo.sp_add_job'+CHAR(10)+
    '        @job_name = N' + QUOTENAME(j.name,'''') + ','+CHAR(10)+
    '        @enabled = ' + CAST(j.enabled AS varchar(10)) + ','+CHAR(10)+
    '        @notify_level_eventlog = ' + CAST(j.notify_level_eventlog AS varchar(10)) + ','+CHAR(10)+
    '        @notify_level_email = ' + CAST(j.notify_level_email AS varchar(10)) + ','+CHAR(10)+
    '        @delete_level = ' + CAST(j.delete_level AS varchar(10)) + ','+CHAR(10)+
    '        @description = N' + COALESCE(QUOTENAME(j.description, ''''), 'NULL') + ','+CHAR(10)+
    '        @owner_login_name = N' + QUOTENAME(COALESCE(SUSER_SNAME(j.owner_sid), 'sa'),'''') + ';'+CHAR(10)+
    'END'+CHAR(10)+
    'GO'+CHAR(10)
AS [-- Jobs Header]
FROM msdb.dbo.sysjobs AS j
ORDER BY j.name;

-- 2) Steps
SELECT
    'EXEC msdb.dbo.sp_add_jobstep'+CHAR(10)+
    '    @job_name = N' + QUOTENAME(j.name,'''') + ','+CHAR(10)+
    '    @step_name = N' + QUOTENAME(s.step_name,'''') + ','+CHAR(10)+
    '    @subsystem = N' + QUOTENAME(s.subsystem,'''') + ','+CHAR(10)+
    '    @command = N''' + REPLACE(CAST(s.command AS nvarchar(max)),'''','''''') + ''','+CHAR(10)+
    '    @database_name = ' + COALESCE(QUOTENAME(s.database_name,'''') ,'NULL') + ','+CHAR(10)+
    '    @retry_attempts = ' + CAST(s.retry_attempts AS varchar(10)) + ','+CHAR(10)+
    '    @retry_interval = ' + CAST(s.retry_interval AS varchar(10)) + ','+CHAR(10)+
    '    @on_success_action = ' + CAST(s.on_success_action AS varchar(10)) + ','+CHAR(10)+
    '    @on_fail_action = ' + CAST(s.on_fail_action AS varchar(10)) + ';'+CHAR(10)+
    'GO'+CHAR(10)
AS [-- Job Steps]
FROM msdb.dbo.sysjobsteps AS s
JOIN msdb.dbo.sysjobs AS j ON j.job_id = s.job_id
ORDER BY j.name, s.step_id;

-- 3) Schedules: create then attach
;WITH JS AS (
  SELECT j.name AS job_name, sch.*
  FROM msdb.dbo.sysjobschedules AS js
  JOIN msdb.dbo.sysschedules AS sch ON sch.schedule_id = js.schedule_id
  JOIN msdb.dbo.sysjobs AS j ON j.job_id = js.job_id
)
SELECT
    '-- Schedule for job ' + QUOTENAME(JS.job_name) + ': ' + QUOTENAME(JS.name) + CHAR(10) +
    'IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = N' + QUOTENAME(JS.name,'''') + ')'+CHAR(10)+
    'BEGIN'+CHAR(10)+
    '    EXEC msdb.dbo.sp_add_schedule'+CHAR(10)+
    '        @schedule_name = N' + QUOTENAME(JS.name,'''') + ','+CHAR(10)+
    '        @enabled = ' + CAST(JS.enabled AS varchar(10)) + ','+CHAR(10)+
    '        @freq_type = ' + CAST(JS.freq_type AS varchar(10)) + ','+CHAR(10)+
    '        @freq_interval = ' + CAST(JS.freq_interval AS varchar(10)) + ','+CHAR(10)+
    '        @freq_subday_type = ' + CAST(JS.freq_subday_type AS varchar(10)) + ','+CHAR(10)+
    '        @freq_subday_interval = ' + CAST(JS.freq_subday_interval AS varchar(10)) + ','+CHAR(10)+
    '        @freq_recurrence_factor = ' + CAST(JS.freq_recurrence_factor AS varchar(10)) + ','+CHAR(10)+
    '        @active_start_date = ' + CAST(JS.active_start_date AS varchar(20)) + ','+CHAR(10)+
    '        @active_start_time = ' + CAST(JS.active_start_time AS varchar(20)) + ';'+CHAR(10)+
    'END'+CHAR(10)+
    'GO'+CHAR(10)+
    'EXEC msdb.dbo.sp_attach_schedule @job_name = N' + QUOTENAME(JS.job_name,'''') + ', @schedule_name = N' + QUOTENAME(JS.name,'''') + ';'+CHAR(10)+
    'GO'+CHAR(10)
AS [-- Schedules]
FROM JS
ORDER BY JS.job_name, JS.name;

-- 4) Target server
SELECT
    'EXEC msdb.dbo.sp_add_jobserver @job_name = N' + QUOTENAME(j.name,'''') + ', @server_name = N''(LOCAL)'';'+CHAR(10)+
    'GO'+CHAR(10)
AS [-- Job Target]
FROM msdb.dbo.sysjobs AS j
ORDER BY j.name;

-- 5) Notifications (requires operators)
SELECT
    'EXEC msdb.dbo.sp_update_job '+CHAR(10)+
    '    @job_name = N' + QUOTENAME(j.name,'''') + ','+CHAR(10)+
    '    @notify_level_email = ' + CAST(j.notify_level_email AS varchar(10)) + ','+CHAR(10)+
    '    @notify_email_operator_name = ' + COALESCE(QUOTENAME(o.name,'''') ,'NULL') + ';'+CHAR(10)+
    'GO'+CHAR(10)
AS [-- Notifications]
FROM msdb.dbo.sysjobs AS j
LEFT JOIN msdb.dbo.sysoperators AS o ON o.id = j.notify_email_operator_id
ORDER BY j.name;
