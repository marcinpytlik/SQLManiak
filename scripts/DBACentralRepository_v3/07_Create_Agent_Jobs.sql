USE [msdb];
GO

/*
===============================================================================
DBACentralRepository v3 - automatyzacja SQL Server Agent

Przed uruchomieniem zmień:
    @BasePath
    @RepositoryServer
    @RepositoryDatabase
    @OwnerLogin

Kolektor główny sam uruchamia audyt zgodności.
Nie dodajemy osobnego kroku T-SQL audytu, aby nie duplikować findingów.
===============================================================================
*/

DECLARE
    @BasePath nvarchar(1000) = N'C:\DBA\DBACentralRepository_v3',
    @RepositoryServer nvarchar(256) = N'scrambler\sql2022',
    @RepositoryDatabase sysname = N'DBACentralRepository',
    @OwnerLogin sysname = N'sa',
    @JobName sysname = N'DBA Central Repository v3 - Daily Pipeline',
    @ScheduleName sysname = N'DBA Central Repository v3 - Daily 01:00';

DECLARE @Collect nvarchar(max) =
    N'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' +
    @BasePath + N'\Collect-DBACentralRepository.ps1" ' +
    N'-ServerListPath "' + @BasePath + N'\Servers.csv" ' +
    N'-RepositoryServerInstance "' + @RepositoryServer + N'" ' +
    N'-RepositoryDatabase "' + @RepositoryDatabase + N'" ' +
    N'-CollectionMode Full';

DECLARE @CollectSsrs nvarchar(max) =
    N'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' +
    @BasePath + N'\Collect-SsrsJobMappings.ps1" ' +
    N'-RepositoryServerInstance "' + @RepositoryServer + N'" ' +
    N'-RepositoryDatabase "' + @RepositoryDatabase + N'"';

DECLARE @GenerateDocumentation nvarchar(max) =
    N'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' +
    @BasePath + N'\Export-JobDocumentationPages.ps1" ' +
    N'-RepositoryServerInstance "' + @RepositoryServer + N'" ' +
    N'-RepositoryDatabase "' + @RepositoryDatabase + N'" ' +
    N'-OutputPath "' + @BasePath +
    N'\ConfluenceExport\03. Dokumentacja jobów"';

DECLARE @ExportReports nvarchar(max) =
    N'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' +
    @BasePath + N'\Export-ConfluenceReports.ps1" ' +
    N'-RepositoryServerInstance "' + @RepositoryServer + N'" ' +
    N'-RepositoryDatabase "' + @RepositoryDatabase + N'" ' +
    N'-OutputPath "' + @BasePath + N'\ConfluenceExport"';

IF EXISTS
(
    SELECT 1
    FROM [msdb].[dbo].[sysjobs]
    WHERE [name] = @JobName
)
BEGIN
    EXEC [msdb].[dbo].[sp_delete_job]
        @job_name = @JobName,
        @delete_unused_schedule = 1;
END;

IF EXISTS
(
    SELECT 1
    FROM [msdb].[dbo].[sysschedules]
    WHERE [name] = @ScheduleName
)
BEGIN
    EXEC [msdb].[dbo].[sp_delete_schedule]
        @schedule_name = @ScheduleName;
END;

EXEC [msdb].[dbo].[sp_add_job]
    @job_name = @JobName,
    @enabled = 1,
    @owner_login_name = @OwnerLogin,
    @description =
        N'Kolekcja DBACentralRepository, mapowanie SSRS, dokumentacja jobów i eksport raportów Confluence.';

EXEC [msdb].[dbo].[sp_add_jobstep]
    @job_name = @JobName,
    @step_name = N'01 - Collect repository',
    @subsystem = N'CmdExec',
    @command = @Collect,
    @on_success_action = 3,
    @on_fail_action = 2;

EXEC [msdb].[dbo].[sp_add_jobstep]
    @job_name = @JobName,
    @step_name = N'02 - Collect SSRS mappings',
    @subsystem = N'CmdExec',
    @command = @CollectSsrs,
    @on_success_action = 3,
    @on_fail_action = 3;

EXEC [msdb].[dbo].[sp_add_jobstep]
    @job_name = @JobName,
    @step_name = N'03 - Generate job documentation',
    @subsystem = N'CmdExec',
    @command = @GenerateDocumentation,
    @on_success_action = 3,
    @on_fail_action = 2;

EXEC [msdb].[dbo].[sp_add_jobstep]
    @job_name = @JobName,
    @step_name = N'04 - Export Confluence reports',
    @subsystem = N'CmdExec',
    @command = @ExportReports,
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC [msdb].[dbo].[sp_add_schedule]
    @schedule_name = @ScheduleName,
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 010000;

EXEC [msdb].[dbo].[sp_attach_schedule]
    @job_name = @JobName,
    @schedule_name = @ScheduleName;

EXEC [msdb].[dbo].[sp_add_jobserver]
    @job_name = @JobName;
GO
