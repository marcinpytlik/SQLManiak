USE msdb;
GO

/* ============================================================
   10_job_step_templates.sql

   Gotowe szablony kroków do wklejenia do istniejących jobów.

   Wariant C:
   - Step 1: Check calendar rule
   - Step 2: Decide controlled skip or real failure
   - Step 10+: właściwe kroki joba

   W SQL Agent ustawienia:
   Step 1:
     On success: Go to step: pierwszy właściwy krok joba
     On failure: Go to step: Decide controlled skip or real failure

   Step 2:
     On success: Quit the job reporting success
     On failure: Quit the job reporting failure
   ============================================================ */

------------------------------------------------------------
-- TEMPLATE A:
-- Job ma działać w każdy dzień roboczy
------------------------------------------------------------
PRINT 'TEMPLATE A - ANY_WORKING_DAY';
PRINT 'Step 1 command:';

PRINT '
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
';

PRINT 'Step 2 command:';

PRINT '
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N''ANY_WORKING_DAY'';

IF @ReturnCode = 10
BEGIN
    PRINT ''Job zakończony kontrolowanie, bo reguła kalendarza nie została spełniona.'';
    RETURN 0;
END;

RAISERROR(''Błąd konfiguracji kalendarza albo nieoczekiwany kod zwrotny.'', 16, 1);
';

------------------------------------------------------------
-- TEMPLATE B:
-- Job ma działać tylko w ostatni dzień roboczy miesiąca
------------------------------------------------------------
PRINT 'TEMPLATE B - LAST_WORKING_DAY_OF_MONTH';
PRINT 'Step 1 command:';

PRINT '
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N''LAST_WORKING_DAY_OF_MONTH'';

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
';

PRINT 'Step 2 command:';

PRINT '
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N''LAST_WORKING_DAY_OF_MONTH'';

IF @ReturnCode = 10
BEGIN
    PRINT ''Job zakończony kontrolowanie, bo reguła kalendarza nie została spełniona.'';
    RETURN 0;
END;

RAISERROR(''Błąd konfiguracji kalendarza albo nieoczekiwany kod zwrotny.'', 16, 1);
';

------------------------------------------------------------
-- TEMPLATE C:
-- Job ma działać tylko w N-ty dzień roboczy miesiąca
------------------------------------------------------------
PRINT 'TEMPLATE C - NTH_WORKING_DAY_OF_MONTH';
PRINT 'Przykład: trzeci dzień roboczy miesiąca.';

PRINT '
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N''NTH_WORKING_DAY_OF_MONTH'',
    @WorkingDayNumberInMonth = 3;

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
';
GO
