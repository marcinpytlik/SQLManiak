USE msdb;
GO

/* ============================================================
   03_create_work_calendar_enriched_view.sql

   Cel:
   - Tworzy widok msdb.dba.vWorkCalendarEnriched.

   Poprawki w tej wersji:
   - Usunięto konstrukcje MIN/MAX(CASE WHEN ... THEN ... END),
     które generowały ostrzeżenie:
     "Null value is eliminated by an aggregate or other SET operation".
   - Dodano IsManualOverride.
   ============================================================ */

CREATE OR ALTER VIEW dba.vWorkCalendarEnriched
AS
WITH BaseCalendar AS
(
    SELECT
        wc.CalendarDate,
        wc.IsWorkingDay,
        wc.Description,
        wc.IsManualOverride,
        wc.CreatedAt,
        wc.ModifiedAt,

        YEAR(wc.CalendarDate) AS CalendarYear,
        MONTH(wc.CalendarDate) AS CalendarMonth,
        DAY(wc.CalendarDate) AS DayOfMonth,

        DATEFROMPARTS(YEAR(wc.CalendarDate), MONTH(wc.CalendarDate), 1) AS MonthStartDate,
        EOMONTH(wc.CalendarDate) AS MonthEndDate,

        /*
            1900-01-01 był poniedziałkiem.
            Wynik:
            1 = poniedziałek
            2 = wtorek
            3 = środa
            4 = czwartek
            5 = piątek
            6 = sobota
            7 = niedziela
        */
        CAST((DATEDIFF(day, CONVERT(date, '19000101'), wc.CalendarDate) % 7) + 1 AS tinyint) AS IsoDayOfWeek
    FROM dba.WorkCalendar AS wc
),
WorkingDays AS
(
    SELECT
        bc.CalendarDate,
        ROW_NUMBER() OVER
        (
            PARTITION BY bc.CalendarYear, bc.CalendarMonth
            ORDER BY bc.CalendarDate
        ) AS WorkingDayNumberInMonth
    FROM BaseCalendar AS bc
    WHERE bc.IsWorkingDay = 1
),
MonthStats AS
(
    SELECT
        bc.CalendarYear,
        bc.CalendarMonth,
        MIN(bc.CalendarDate) AS FirstWorkingDayOfMonth,
        MAX(bc.CalendarDate) AS LastWorkingDayOfMonth,
        COUNT_BIG(*) AS WorkingDaysInMonth
    FROM BaseCalendar AS bc
    WHERE bc.IsWorkingDay = 1
    GROUP BY
        bc.CalendarYear,
        bc.CalendarMonth
)
SELECT
    bc.CalendarDate,
    bc.IsWorkingDay,
    bc.Description,
    bc.IsManualOverride,

    bc.CalendarYear,
    bc.CalendarMonth,
    bc.DayOfMonth,
    bc.MonthStartDate,
    bc.MonthEndDate,

    bc.IsoDayOfWeek,

    CASE bc.IsoDayOfWeek
        WHEN 1 THEN N'Poniedziałek'
        WHEN 2 THEN N'Wtorek'
        WHEN 3 THEN N'Środa'
        WHEN 4 THEN N'Czwartek'
        WHEN 5 THEN N'Piątek'
        WHEN 6 THEN N'Sobota'
        WHEN 7 THEN N'Niedziela'
    END AS DayNamePL,

    CAST(CASE WHEN bc.IsoDayOfWeek IN (6, 7) THEN 1 ELSE 0 END AS bit) AS IsWeekend,

    CAST
    (
        CASE
            WHEN bc.IsWorkingDay = 0
             AND
             (
                 bc.IsManualOverride = 1
                 OR bc.IsoDayOfWeek NOT IN (6, 7)
             )
                THEN 1
            ELSE 0
        END AS bit
    ) AS IsHolidayOrCompanyDayOff,

    ms.FirstWorkingDayOfMonth,
    ms.LastWorkingDayOfMonth,

    CAST
    (
        CASE
            WHEN bc.IsWorkingDay = 1
             AND bc.CalendarDate = ms.FirstWorkingDayOfMonth
                THEN 1
            ELSE 0
        END AS bit
    ) AS IsFirstWorkingDayOfMonth,

    CAST
    (
        CASE
            WHEN bc.IsWorkingDay = 1
             AND bc.CalendarDate = ms.LastWorkingDayOfMonth
                THEN 1
            ELSE 0
        END AS bit
    ) AS IsLastWorkingDayOfMonth,

    wd.WorkingDayNumberInMonth,
    CONVERT(int, ms.WorkingDaysInMonth) AS WorkingDaysInMonth,

    prevwd.CalendarDate AS PreviousWorkingDay,
    nextwd.CalendarDate AS NextWorkingDay,

    bc.CreatedAt,
    bc.ModifiedAt
FROM BaseCalendar AS bc
LEFT JOIN WorkingDays AS wd
    ON wd.CalendarDate = bc.CalendarDate
LEFT JOIN MonthStats AS ms
    ON ms.CalendarYear = bc.CalendarYear
   AND ms.CalendarMonth = bc.CalendarMonth
OUTER APPLY
(
    SELECT TOP (1)
        x.CalendarDate
    FROM BaseCalendar AS x
    WHERE x.IsWorkingDay = 1
      AND x.CalendarDate < bc.CalendarDate
    ORDER BY x.CalendarDate DESC
) AS prevwd
OUTER APPLY
(
    SELECT TOP (1)
        x.CalendarDate
    FROM BaseCalendar AS x
    WHERE x.IsWorkingDay = 1
      AND x.CalendarDate > bc.CalendarDate
    ORDER BY x.CalendarDate ASC
) AS nextwd;
GO

-- Weryfikacja
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
