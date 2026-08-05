USE [msdb];
GO

/*
===============================================================================
18_Create_Database_Documentation_Agent_Job.sql

Szablon opcjonalnego joba.
Przed uruchomieniem zmień:
- ścieżkę do repozytorium,
- nazwę instancji repozytorium,
- nazwę bazy repozytorium,
- konto/proxy SQL Server Agent.
===============================================================================
*/

DECLARE
    @JobName sysname =
        N'DBA - DBACentralRepository - Database Documentation',
    @JobDescription nvarchar(512),
    @CollectCommand nvarchar(max),
    @ExportCommand nvarchar(max);

SET @JobDescription =
    N'Skan struktury baz i generowanie dokumentacji. '
    + N'Job jest tworzony jako wyłączony. '
    + N'Przed włączeniem należy uzupełnić ścieżki i konto uruchomieniowe.';

SET @CollectCommand =
    N'& ''C:\DBA\DBACentralRepository\Collect-DatabaseSchema.ps1'' '
    + N'-RepositoryServerInstance ''scrambler\sql2022'' '
    + N'-RepositoryDatabase ''DBACentralRepository''';

SET @ExportCommand =
    N'& ''C:\DBA\DBACentralRepository\Export-DatabaseDocumentationPages.ps1'' '
    + N'-RepositoryServerInstance ''scrambler\sql2022'' '
    + N'-RepositoryDatabase ''DBACentralRepository''';

IF NOT EXISTS
(
    SELECT 1
    FROM [dbo].[sysjobs]
    WHERE [name] = @JobName
)
BEGIN
    EXEC [dbo].[sp_add_job]
        @job_name = @JobName,
        @enabled = 0,
        @description = @JobDescription;

    EXEC [dbo].[sp_add_jobstep]
        @job_name = @JobName,
        @step_name = N'01 - Collect database schema',
        @subsystem = N'PowerShell',
        @command = @CollectCommand,
        @on_success_action = 3,
        @on_fail_action = 2;

    EXEC [dbo].[sp_add_jobstep]
        @job_name = @JobName,
        @step_name = N'02 - Export database documentation',
        @subsystem = N'PowerShell',
        @command = @ExportCommand,
        @on_success_action = 1,
        @on_fail_action = 2;

    EXEC [dbo].[sp_add_jobserver]
        @job_name = @JobName;

    PRINT N'Utworzono wyłączony job: ' + @JobName;
END
ELSE
BEGIN
    PRINT N'Job już istnieje: ' + @JobName;
END;
GO