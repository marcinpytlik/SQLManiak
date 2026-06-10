USE msdb;
GO

/* ============================================================
   06_example_job_variant_c_last_working_day.sql

   Cel:
   - Przykładowy job miesięczny.
   - Właściwe kroki wykonają się tylko w ostatni dzień roboczy miesiąca.
   - Przydatne dla raportów miesięcznych, zamknięcia miesiąca,
     eksportów księgowych, paczek kontrolnych.
   ============================================================ */

DECLARE @JobName sysname = N'DBA - Work Calendar - Last Working Day Of Month';
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
    @description = N'Job wykonuje właściwe kroki tylko w ostatni dzień roboczy miesiąca.',
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
    @RuleName = N''LAST_WORKING_DAY_OF_MONTH'';

IF @ReturnCode = 0
BEGIN
    PRINT ''Ostatni dzień roboczy miesiąca - przechodzę do właściwych kroków.'';
    RETURN 0;
END;

IF @ReturnCode = 10
BEGIN
    PRINT ''To nie jest ostatni dzień roboczy miesiąca - kontrolowane zakończenie.'';
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
    @RuleName = N''LAST_WORKING_DAY_OF_MONTH'';

IF @ReturnCode = 10
BEGIN
    PRINT ''Job zakończony kontrolowanie, bo to nie jest ostatni dzień roboczy miesiąca.'';
    RETURN 0;
END;

RAISERROR(''Błąd konfiguracji kalendarza albo nieoczekiwany kod zwrotny.'', 16, 1);
',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobId,
    @step_id = 10,
    @step_name = N'Month end business step',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'
PRINT ''Właściwy krok joba miesięcznego uruchomiony w ostatni dzień roboczy miesiąca.'';
',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @JobId,
    @server_name = N'(LOCAL)';
GO
