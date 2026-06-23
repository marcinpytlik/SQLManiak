USE msdb;
GO

/* ============================================================
   Przykładowy job sterowany kalendarzem dni roboczych.

   Poprawki w tej wersji:
   - Brak RETURN 0 w krokach T-SQL SQL Agenta.
   - Brak referencji do nieistniejących kroków podczas tworzenia joba.
   - Kroki mają numerację ciągłą: 1, 2, 3.
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

------------------------------------------------------------
-- Krok 1 tworzymy tymczasowo bez skoków do kroków 2 i 3.
-- Finalne przejścia ustawiamy dopiero po utworzeniu wszystkich kroków.
------------------------------------------------------------
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
    RETURN;
END;

IF @ReturnCode = 10
BEGIN
    PRINT ''Reguła niespełniona - kontrolowane zakończenie joba.'';
    RAISERROR(''CONTROLLED_SKIP'', 16, 1);
    RETURN;
END;

RAISERROR(''WORK_CALENDAR_CONFIGURATION_ERROR'', 16, 1);
',
    @on_success_action = 3,
    @on_fail_action = 3;

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
    RETURN;
END;

RAISERROR(''Błąd konfiguracji kalendarza albo nieoczekiwany kod zwrotny.'', 16, 1);
',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobId,
    @step_id = 3,
    @step_name = N'Business step 1',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'
PRINT ''Właściwy krok joba uruchomiony w dzień roboczy.'';
',
    @on_success_action = 1,
    @on_fail_action = 2;

------------------------------------------------------------
-- Finalna logika:
-- sukces kroku 1 -> krok 3, czyli właściwa praca
-- błąd kroku 1   -> krok 2, czyli controlled skip albo real failure
------------------------------------------------------------
EXEC msdb.dbo.sp_update_jobstep
    @job_id = @JobId,
    @step_id = 1,
    @on_success_action = 4,
    @on_success_step_id = 3,
    @on_fail_action = 4,
    @on_fail_step_id = 2;

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @JobId,
    @server_name = N'(LOCAL)';
GO

-- Weryfikacja struktury joba
SELECT
    j.name AS JobName,
    s.step_id,
    s.step_name,
    s.subsystem,
    s.database_name,
    s.on_success_action,
    s.on_success_step_id,
    s.on_fail_action,
    s.on_fail_step_id
FROM msdb.dbo.sysjobs AS j
INNER JOIN msdb.dbo.sysjobsteps AS s
    ON s.job_id = j.job_id
WHERE j.name = N'DBA - Work Calendar - Any Working Day'
ORDER BY s.step_id;
GO

-- Opcjonalne ręczne uruchomienie joba:
-- EXEC msdb.dbo.sp_start_job @job_name = N'DBA - Work Calendar - Any Working Day';
-- GO
