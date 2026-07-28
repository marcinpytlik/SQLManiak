USE msdb;
GO

DECLARE @BasePath nvarchar(1000)=N'C:\DBA\DBACentralRepository_v3';
DECLARE @RepositoryServer nvarchar(256)=N'SQLCENTRAL';
DECLARE @OwnerLogin sysname=N'sa';

DECLARE @Full nvarchar(max)=
N'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "'+@BasePath+
N'\Collect-DBACentralRepository.ps1" -ServerListPath "'+@BasePath+
N'\Servers.csv" -RepositoryServerInstance "'+@RepositoryServer+N'" -CollectionMode Full';

DECLARE @Export nvarchar(max)=
N'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "'+@BasePath+
N'\Export-ConfluenceReports.ps1" -RepositoryServerInstance "'+@RepositoryServer+
N'" -OutputPath "'+@BasePath+N'\ConfluenceExport"';

IF EXISTS(SELECT 1 FROM msdb.dbo.sysjobs WHERE name=N'DBA Central Repository v3 - Daily Full')
    EXEC msdb.dbo.sp_delete_job @job_name=N'DBA Central Repository v3 - Daily Full';

EXEC msdb.dbo.sp_add_job
    @job_name=N'DBA Central Repository v3 - Daily Full',
    @enabled=1,
    @owner_login_name=@OwnerLogin,
    @description=N'Pełny dzienny skan Etapów 1 i 2 wraz z audytem zgodności.';

EXEC msdb.dbo.sp_add_jobstep
    @job_name=N'DBA Central Repository v3 - Daily Full',
    @step_name=N'01 - Pełny skan',
    @subsystem=N'CmdExec',
    @command=@Full,
    @on_success_action=3,
    @on_fail_action=2;

EXEC msdb.dbo.sp_add_jobstep
    @job_name=N'DBA Central Repository v3 - Daily Full',
    @step_name=N'02 - Audyt zgodności',
    @subsystem=N'TSQL',
    @database_name=N'DBACentralRepository',
    @command=N'DECLARE @Id bigint; EXEC audit.usp_RunJobComplianceAudit @ComplianceRunId=@Id OUTPUT;',
    @on_success_action=1,
    @on_fail_action=2;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name=N'DBA Central Repository v3 - Daily 01:00',
    @enabled=1,@freq_type=4,@freq_interval=1,@active_start_time=010000;

EXEC msdb.dbo.sp_attach_schedule
    @job_name=N'DBA Central Repository v3 - Daily Full',
    @schedule_name=N'DBA Central Repository v3 - Daily 01:00';

EXEC msdb.dbo.sp_add_jobserver
    @job_name=N'DBA Central Repository v3 - Daily Full';

IF EXISTS(SELECT 1 FROM msdb.dbo.sysjobs WHERE name=N'DBA Central Repository v3 - Export')
    EXEC msdb.dbo.sp_delete_job @job_name=N'DBA Central Repository v3 - Export';

EXEC msdb.dbo.sp_add_job
    @job_name=N'DBA Central Repository v3 - Export',
    @enabled=1,
    @owner_login_name=@OwnerLogin,
    @description=N'Eksport CSV i HTML do Confluence.';

EXEC msdb.dbo.sp_add_jobstep
    @job_name=N'DBA Central Repository v3 - Export',
    @step_name=N'01 - Eksportuj raporty',
    @subsystem=N'CmdExec',
    @command=@Export,
    @on_success_action=1,
    @on_fail_action=2;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name=N'DBA Central Repository v3 - Daily 02:00',
    @enabled=1,@freq_type=4,@freq_interval=1,@active_start_time=020000;

EXEC msdb.dbo.sp_attach_schedule
    @job_name=N'DBA Central Repository v3 - Export',
    @schedule_name=N'DBA Central Repository v3 - Daily 02:00';

EXEC msdb.dbo.sp_add_jobserver
    @job_name=N'DBA Central Repository v3 - Export';
GO
