/* sql/40_agent_job.sql
   Przykładowy SQL Agent Job: nocne ładowanie agregatów z poprzedniej doby
*/

DECLARE @job_name sysname = N'AuditDailyAgg Loader';
DECLARE @AuditName sysname = N'DBAudit';  -- <--- PODAJ SWÓJ AUDYT

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name=@job_name)
BEGIN
    EXEC msdb.dbo.sp_add_job @job_name=@job_name, @description=N'Ładowanie dziennych agregatów z plików SQL Audit';
    EXEC msdb.dbo.sp_add_jobstep
        @job_name=@job_name,
        @step_name=N'LoadYesterday',
        @subsystem=N'TSQL',
        @command=N'
DECLARE @to   date = CAST(SYSDATETIME() AS date);
DECLARE @from date = DATEADD(day,-1,@to);
EXEC dbo.Refresh_AuditDailyAgg @AuditName = N'''+REPLACE(str(@AuditName), ' ', ' ')+r'''', @FromDate=@from, @ToDate=@to;',
        @database_name = N'master';
    EXEC msdb.dbo.sp_add_schedule 
        @schedule_name = N'AuditDailyAgg_Daily_0010',
        @freq_type = 4,             -- daily
        @freq_interval = 1,
        @active_start_time = 001000; -- 00:10
    EXEC msdb.dbo.sp_attach_schedule @job_name=@job_name, @schedule_name=N'AuditDailyAgg_Daily_0010';
    EXEC msdb.dbo.sp_add_jobserver  @job_name=@job_name; -- domyślny serwer
END
ELSE
BEGIN
    PRINT 'Job już istnieje: ' + @job_name;
END
