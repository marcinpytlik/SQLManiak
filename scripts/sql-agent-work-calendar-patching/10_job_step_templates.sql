USE msdb;
GO

/* ============================================================
   10_job_step_templates.sql

   Gotowe szablony kroków do wklejenia do istniejących jobów.

   Poprawki w tej wersji:
   - W krokach T-SQL SQL Agenta nie używamy RETURN 0.
   - Używamy RETURN bez wartości.
   - CONTROLLED_SKIP celowo kończy krok 1 błędem, aby SQL Agent
     przeszedł do kroku decyzyjnego.
   ============================================================ */

------------------------------------------------------------
-- TEMPLATE A:
-- Step 1: Check calendar rule
-- Job ma działać w każdy dzień roboczy
------------------------------------------------------------
PRINT 'TEMPLATE A - ANY_WORKING_DAY - STEP 1';
PRINT '
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
';
GO

PRINT 'TEMPLATE A - ANY_WORKING_DAY - STEP 2';
PRINT '
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N''ANY_WORKING_DAY'';

IF @ReturnCode = 10
BEGIN
    PRINT ''Job zakończony kontrolowanie, bo reguła kalendarza nie została spełniona.'';
    RETURN;
END;

RAISERROR(''Błąd konfiguracji kalendarza albo nieoczekiwany kod zwrotny.'', 16, 1);
';
GO

------------------------------------------------------------
-- TEMPLATE B:
-- Job ma działać tylko w ostatni dzień roboczy miesiąca
------------------------------------------------------------
PRINT 'TEMPLATE B - LAST_WORKING_DAY_OF_MONTH - STEP 1';
PRINT '
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N''LAST_WORKING_DAY_OF_MONTH'';

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
';
GO

PRINT 'TEMPLATE B - LAST_WORKING_DAY_OF_MONTH - STEP 2';
PRINT '
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N''LAST_WORKING_DAY_OF_MONTH'';

IF @ReturnCode = 10
BEGIN
    PRINT ''Job zakończony kontrolowanie, bo reguła kalendarza nie została spełniona.'';
    RETURN;
END;

RAISERROR(''Błąd konfiguracji kalendarza albo nieoczekiwany kod zwrotny.'', 16, 1);
';
GO

------------------------------------------------------------
-- TEMPLATE C:
-- Job ma działać tylko w N-ty dzień roboczy miesiąca
------------------------------------------------------------
PRINT 'TEMPLATE C - NTH_WORKING_DAY_OF_MONTH - STEP 1';
PRINT 'Przykład: trzeci dzień roboczy miesiąca.';
PRINT '
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N''NTH_WORKING_DAY_OF_MONTH'',
    @WorkingDayNumberInMonth = 3;

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
';
GO

PRINT 'TEMPLATE C - NTH_WORKING_DAY_OF_MONTH - STEP 2';
PRINT '
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N''NTH_WORKING_DAY_OF_MONTH'',
    @WorkingDayNumberInMonth = 3;

IF @ReturnCode = 10
BEGIN
    PRINT ''Job zakończony kontrolowanie, bo reguła kalendarza nie została spełniona.'';
    RETURN;
END;

RAISERROR(''Błąd konfiguracji kalendarza albo nieoczekiwany kod zwrotny.'', 16, 1);
';
GO
