USE msdb;
GO

/* ============================================================
   09_manual_company_day_off_example.sql

   Cel:
   - Przykład ręcznego oznaczenia dnia firmowego jako wolnego.
   - Przydatne dla:
     - mostków,
     - dni wolnych za święto przypadające w sobotę,
     - zamknięcia firmy,
     - decyzji organizacyjnych.
   ============================================================ */

DECLARE @CompanyDayOff date = '2026-08-14';

UPDATE dba.WorkCalendar
SET
    IsWorkingDay = 0,
    Description = N'Dzień wolny firmowy za święto przypadające w sobotę',
    ModifiedAt = sysdatetime()
WHERE CalendarDate = @CompanyDayOff;

SELECT
    CalendarDate,
    IsWorkingDay,
    Description,
    DayNamePL,
    IsFirstWorkingDayOfMonth,
    IsLastWorkingDayOfMonth,
    WorkingDayNumberInMonth,
    WorkingDaysInMonth,
    ModifiedAt
FROM dba.vWorkCalendarEnriched
WHERE CalendarDate = @CompanyDayOff;
GO
