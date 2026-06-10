USE msdb;
GO

/* ============================================================
   05_example_job_variant_c_any_working_day.sql

   Cel:
   - Przykładowy job uruchamiany tylko w zwykły dzień roboczy.
   - Jeśli dzień wolny: job kończy się sukcesem.
   - Jeśli brak wpisu: job kończy się błędem.
   ============================================================ */

DECLARE @JobName sysname = N'DBA - Work Calendar - Any Working Day';
DECLARE @JobId uniqueidentifier;

IF EXISTS
(
    SELECT 1
    FROM msdb.dbo.sysjobs
    WHERE name = @JobName
)
BEGIN
    EXEC msdb.dbo.sp_delete_job
        @job_name = @JobName,
        @delete_unused_schedule = 1;
END;

EXEC msdb.dbo.sp_add_job
    @job_name = @JobName,
    @enabled = 1,
    @description = N'Job wykonuje właściwe kroki tylko w dowolny dzień roboczy.',
    @owner_login_name = N'sa',
    @job_id = @JobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobId,
    @step_id = 1,
    @step_name = N'Check calendar rule',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N''ANY_WORKING_DAY'';

IF @ReturnCode = 0
BEGIN
    PRINT ''Reguła spełniona - przechodzę do właściwych kroków joba.'';
    RETURN 0;
END;

IF @ReturnCode = 10
BEGIN
    PRINT ''Reguła niespełniona - kontrolowane zakończenie joba.'';
    RAISERROR(''CONTROLLED_SKIP'', 16, 1);
    RETURN;
END;

RAISERROR(''WORK_CALENDAR_CONFIGURATION_ERROR'', 16, 1);
',
    @on_success_action = 4,
    @on_success_step_id = 10,
    @on_fail_action = 4,
    @on_fail_step_id = 2;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobId,
    @step_id = 2,
    @step_name = N'Decide controlled skip or real failure',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N''ANY_WORKING_DAY'';

IF @ReturnCode = 10
BEGIN
    PRINT ''Job zakończony kontrolowanie, bo reguła kalendarza nie została spełniona.'';
    RETURN 0;
END;

RAISERROR(''Błąd konfiguracji kalendarza albo nieoczekiwany kod zwrotny.'', 16, 1);
',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobId,
    @step_id = 10,
    @step_name = N'Business step 1',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'
PRINT ''Właściwy krok joba uruchomiony w dzień roboczy.'';
',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @JobId,
    @server_name = N'(LOCAL)';
GO
