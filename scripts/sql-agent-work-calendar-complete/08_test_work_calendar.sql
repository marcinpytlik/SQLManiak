USE msdb;
GO

/* ============================================================
   08_test_work_calendar.sql

   Bezpieczny zestaw testów.
   Ten skrypt nie modyfikuje kalendarza.
   ============================================================ */

------------------------------------------------------------
-- 1. Dzisiejszy wpis w widoku wzbogaconym
------------------------------------------------------------
SELECT
    CalendarDate,
    IsWorkingDay,
    Description,
    IsManualOverride,
    DayNamePL,
    IsWeekend,
    IsHolidayOrCompanyDayOff,
    IsFirstWorkingDayOfMonth,
    IsLastWorkingDayOfMonth,
    WorkingDayNumberInMonth,
    WorkingDaysInMonth,
    PreviousWorkingDay,
    NextWorkingDay
FROM dba.vWorkCalendarEnriched
WHERE CalendarDate = CONVERT(date, GETDATE());
GO

------------------------------------------------------------
-- 2. Najbliższe 30 dni wolnych
------------------------------------------------------------
SELECT TOP (30)
    CalendarDate,
    IsWorkingDay,
    Description,
    IsManualOverride,
    DayNamePL,
    IsWeekend,
    IsHolidayOrCompanyDayOff
FROM dba.vWorkCalendarEnriched
WHERE CalendarDate >= CONVERT(date, GETDATE())
  AND IsWorkingDay = 0
ORDER BY CalendarDate;
GO

------------------------------------------------------------
-- 3. Pierwsze i ostatnie dni robocze miesięcy
------------------------------------------------------------
SELECT
    CalendarYear,
    CalendarMonth,
    MAX(FirstWorkingDayOfMonth) AS FirstWorkingDayOfMonth,
    MAX(LastWorkingDayOfMonth) AS LastWorkingDayOfMonth,
    MAX(WorkingDaysInMonth) AS WorkingDaysInMonth
FROM dba.vWorkCalendarEnriched
WHERE CalendarDate >= DATEFROMPARTS(YEAR(GETDATE()), 1, 1)
  AND CalendarDate <  DATEFROMPARTS(YEAR(GETDATE()) + 1, 1, 1)
GROUP BY
    CalendarYear,
    CalendarMonth
ORDER BY
    CalendarYear,
    CalendarMonth;
GO

------------------------------------------------------------
-- 4. Wszystkie ostatnie dni robocze miesiąca w bieżącym roku
------------------------------------------------------------
SELECT
    CalendarDate,
    Description,
    DayNamePL,
    WorkingDayNumberInMonth,
    WorkingDaysInMonth
FROM dba.vWorkCalendarEnriched
WHERE CalendarYear = YEAR(GETDATE())
  AND IsLastWorkingDayOfMonth = 1
ORDER BY CalendarDate;
GO

------------------------------------------------------------
-- 5. Sprawdzenie podstawowej procedury dla dzisiaj
------------------------------------------------------------
DECLARE @ReturnCodeBasic int;

EXEC @ReturnCodeBasic = msdb.dba.usp_CheckWorkCalendarForSqlAgent;

SELECT @ReturnCodeBasic AS ReturnCodeBasic;
GO

------------------------------------------------------------
-- 6. Sprawdzenie reguły: dowolny dzień roboczy
------------------------------------------------------------
DECLARE @ReturnCodeAny int;

EXEC @ReturnCodeAny = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N'ANY_WORKING_DAY';

SELECT @ReturnCodeAny AS ReturnCodeAnyWorkingDay;
GO

------------------------------------------------------------
-- 7. Sprawdzenie reguły: pierwszy dzień roboczy miesiąca
------------------------------------------------------------
DECLARE @ReturnCodeFirst int;

EXEC @ReturnCodeFirst = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N'FIRST_WORKING_DAY_OF_MONTH';

SELECT @ReturnCodeFirst AS ReturnCodeFirstWorkingDayOfMonth;
GO

------------------------------------------------------------
-- 8. Sprawdzenie reguły: ostatni dzień roboczy miesiąca
------------------------------------------------------------
DECLARE @ReturnCodeLast int;

EXEC @ReturnCodeLast = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N'LAST_WORKING_DAY_OF_MONTH';

SELECT @ReturnCodeLast AS ReturnCodeLastWorkingDayOfMonth;
GO

------------------------------------------------------------
-- 9. Sprawdzenie reguły: trzeci dzień roboczy miesiąca
------------------------------------------------------------
DECLARE @ReturnCodeThird int;

EXEC @ReturnCodeThird = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N'NTH_WORKING_DAY_OF_MONTH',
    @WorkingDayNumberInMonth = 3;

SELECT @ReturnCodeThird AS ReturnCodeThirdWorkingDayOfMonth;
GO

------------------------------------------------------------
-- 10. Testy na konkretnych datach bez modyfikowania tabeli
------------------------------------------------------------
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N'ANY_WORKING_DAY',
    @CheckDate = '2026-06-23';

SELECT @ReturnCode AS ReturnCodeForSpecificDate;
GO
