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
-- weryfikacja

USE msdb;
GO

SELECT
    job_id,
    name,
    enabled,
    date_created,
    date_modified
FROM msdb.dbo.sysjobs
WHERE name = N'DBA - Work Calendar - Any Working Day';
GO

--Sprawdźmy kroki joba.

USE msdb;
GO

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

--Tutaj zobaczymy strukturę:

--Step 1  Check calendar rule
--Step 2  Decide controlled skip or real failure
--Step 10 Business step 1
-- Uruchomienie joba na żywo

--Teraz uruchamiam joba ręcznie.

USE msdb;
GO

EXEC msdb.dbo.sp_start_job
    @job_name = N'DBA - Work Calendar - Any Working Day';
GO

--Po chwili sprawdzamy historię.

USE msdb;
GO

SELECT TOP (20)
    j.name AS JobName,
    h.step_id,
    h.step_name,
    h.run_status,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In progress'
    END AS RunStatusDescription,
    h.run_date,
    h.run_time,
    h.message
FROM msdb.dbo.sysjobhistory AS h
INNER JOIN msdb.dbo.sysjobs AS j
    ON j.job_id = h.job_id
WHERE j.name = N'DBA - Work Calendar - Any Working Day'
ORDER BY h.instance_id DESC;
GO

--11. Symulacja dnia wolnego

USE msdb;
GO

SELECT
    CalendarDate,
    IsWorkingDay,
    Description
FROM dba.WorkCalendar
WHERE CalendarDate = CONVERT(date, GETDATE());
GO

--Teraz tymczasowo ustawiam dzisiejszy dzień jako wolny.

USE msdb;
GO

UPDATE dba.WorkCalendar
SET
    IsWorkingDay = 0,
    Description = N'Test - dzień wolny',
    ModifiedAt = sysdatetime()
WHERE CalendarDate = CONVERT(date, GETDATE());
GO

--Uruchamiam joba jeszcze raz.

USE msdb;
GO

EXEC msdb.dbo.sp_start_job
    @job_name = N'DBA - Work Calendar - Any Working Day';
GO

--Po chwili sprawdzam historię.

USE msdb;
GO

SELECT TOP (20)
    j.name AS JobName,
    h.step_id,
    h.step_name,
    h.run_status,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In progress'
    END AS RunStatusDescription,
    h.run_date,
    h.run_time,
    h.message
FROM msdb.dbo.sysjobhistory AS h
INNER JOIN msdb.dbo.sysjobs AS j
    ON j.job_id = h.job_id
WHERE j.name = N'DBA - Work Calendar - Any Working Day'
ORDER BY h.instance_id DESC;
GO


USE msdb;
GO

UPDATE dba.WorkCalendar
SET
    IsWorkingDay = 1,
    Description = N'Test - dzień roboczy',
    ModifiedAt = sysdatetime()
WHERE CalendarDate = CONVERT(date, GETDATE());
GO
--12. Symulacja błędu konfiguracji


USE msdb;
GO

DECLARE @Today date = CONVERT(date, GETDATE());

SELECT *
INTO #TodayBackup
FROM dba.WorkCalendar
WHERE CalendarDate = @Today;

DELETE FROM dba.WorkCalendar
WHERE CalendarDate = @Today;

SELECT * FROM #TodayBackup;
GO

--Uruchamiam joba.

USE msdb;
GO

EXEC msdb.dbo.sp_start_job
    @job_name = N'DBA - Work Calendar - Any Working Day';
GO

--Sprawdzam historię.

USE msdb;
GO

SELECT TOP (20)
    j.name AS JobName,
    h.step_id,
    h.step_name,
    h.run_status,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In progress'
    END AS RunStatusDescription,
    h.run_date,
    h.run_time,
    h.message
FROM msdb.dbo.sysjobhistory AS h
INNER JOIN msdb.dbo.sysjobs AS j
    ON j.job_id = h.job_id
WHERE j.name = N'DBA - Work Calendar - Any Working Day'
ORDER BY h.instance_id DESC;
GO

--
USE msdb;
GO

DECLARE @Today date = CONVERT(date, GETDATE());

INSERT INTO dba.WorkCalendar
(
    CalendarDate,
    IsWorkingDay,
    Description
)
SELECT
    @Today,
    CASE
        WHEN DATEDIFF(day, '19000101', @Today) % 7 IN (5, 6)
            THEN 0
        ELSE 1
    END,
    CASE
        WHEN DATEDIFF(day, '19000101', @Today) % 7 = 5
            THEN N'Sobota'
        WHEN DATEDIFF(day, '19000101', @Today) % 7 = 6
            THEN N'Niedziela'
        ELSE N'Dzień roboczy'
    END
WHERE NOT EXISTS
(
    SELECT 1
    FROM dba.WorkCalendar
    WHERE CalendarDate = @Today
);
GO
--13. Przykład joba na ostatni dzień roboczy miesiąca

--DEMO — uruchomienie skryptu 06
USE msdb;
GO

-- uruchom zawartość pliku:
-- 06_example_job_variant_c_last_working_day.sql

--Sprawdzamy kroki joba.

USE msdb;
GO

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
WHERE j.name = N'DBA - Work Calendar - Last Working Day Of Month'
ORDER BY s.step_id;
GO

--I teraz uruchamiamy joba ręcznie.

USE msdb;
GO

EXEC msdb.dbo.sp_start_job
    @job_name = N'DBA - Work Calendar - Last Working Day Of Month';
GO

