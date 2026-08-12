USE [msdb];
GO

/*
DBACentralRepository v3 - PERF Collector job
Uruchamiany niezależnie od dziennego pipeline'u Confluence/inwentaryzacji.
*/
DECLARE
    @BasePath nvarchar(1000) = N'C:\DBA\DBACentralRepository_v3',
    @RepositoryServer nvarchar(256) = N'scrambler\sql2022',
    @RepositoryDatabase sysname = N'DBACentralRepository',
    @OwnerLogin sysname = N'sa',
    @JobName sysname = N'DBA Central Repository v3 - PERF Collector',
    @ScheduleName sysname = N'DBA Central Repository v3 - PERF every 5 minutes';

DECLARE @Command nvarchar(max) =
    N'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' +
    @BasePath + N'\Collect-DatabasePerformance.ps1" ' +
    N'-RepositoryServerInstance "' + @RepositoryServer + N'" ' +
    N'-RepositoryDatabase "' + @RepositoryDatabase + N'"';

IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = @JobName)
BEGIN
    EXEC dbo.sp_delete_job @job_name=@JobName, @delete_unused_schedule=1;
END;

IF EXISTS (SELECT 1 FROM dbo.sysschedules WHERE name = @ScheduleName)
BEGIN
    EXEC dbo.sp_delete_schedule @schedule_name=@ScheduleName;
END;

EXEC dbo.sp_add_job
    @job_name=@JobName,
    @enabled=1,
    @owner_login_name=@OwnerLogin,
    @description=N'DBACentralRepository: lekki sampling CPU/I/O/Buffer Pool/log/blocking per database.';

EXEC dbo.sp_add_jobstep
    @job_name=@JobName,
    @step_name=N'01 - Collect database performance',
    @subsystem=N'CmdExec',
    @command=@Command,
    @on_success_action=1,
    @on_fail_action=2;

EXEC dbo.sp_add_schedule
    @schedule_name=@ScheduleName,
    @enabled=1,
    @freq_type=4,
    @freq_interval=1,
    @freq_subday_type=4,
    @freq_subday_interval=5,
    @active_start_time=000000;

EXEC dbo.sp_attach_schedule @job_name=@JobName, @schedule_name=@ScheduleName;
EXEC dbo.sp_add_jobserver @job_name=@JobName;
GO
