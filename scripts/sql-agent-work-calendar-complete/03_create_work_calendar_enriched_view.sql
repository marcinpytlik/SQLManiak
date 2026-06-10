USE msdb;
GO

/* ============================================================
   03_create_work_calendar_enriched_view.sql

   Cel:
   - Tworzy widok msdb.dba.vWorkCalendarEnriched.

   Widok dodaje informacje przydatne dla jobów:
   - rok, miesiąc, dzień,
   - początek i koniec miesiąca,
   - pierwszy dzień roboczy miesiąca,
   - ostatni dzień roboczy miesiąca,
   - numer dnia roboczego w miesiącu,
   - liczba dni roboczych w miesiącu,
   - czy data jest pierwszym/ostatnim dniem roboczym miesiąca,
   - poprzedni i następny dzień roboczy,
   - czy jest weekendem,
   - czy jest świętem ustawowym/firmowym według opisu.
   ============================================================ */

CREATE OR ALTER VIEW dba.vWorkCalendarEnriched
AS
WITH BaseCalendar AS
(
    SELECT
        wc.CalendarDate,
        wc.IsWorkingDay,
        wc.Description,
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
        CAST((DATEDIFF(day, '19000101', wc.CalendarDate) % 7) + 1 AS tinyint) AS IsoDayOfWeek
    FROM dba.WorkCalendar AS wc
),
Calculated AS
(
    SELECT
        bc.CalendarDate,
        bc.IsWorkingDay,
        bc.Description,
        bc.CreatedAt,
        bc.ModifiedAt,

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
                 AND bc.Description NOT IN (N'Sobota', N'Niedziela')
                    THEN 1
                ELSE 0
            END AS bit
        ) AS IsHolidayOrCompanyDayOff,

        MIN(CASE WHEN bc.IsWorkingDay = 1 THEN bc.CalendarDate END)
            OVER
            (
                PARTITION BY bc.CalendarYear, bc.CalendarMonth
            ) AS FirstWorkingDayOfMonth,

        MAX(CASE WHEN bc.IsWorkingDay = 1 THEN bc.CalendarDate END)
            OVER
            (
                PARTITION BY bc.CalendarYear, bc.CalendarMonth
            ) AS LastWorkingDayOfMonth,

        SUM(CASE WHEN bc.IsWorkingDay = 1 THEN 1 ELSE 0 END)
            OVER
            (
                PARTITION BY bc.CalendarYear, bc.CalendarMonth
                ORDER BY bc.CalendarDate
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS WorkingDayNumberInMonth,

        SUM(CASE WHEN bc.IsWorkingDay = 1 THEN 1 ELSE 0 END)
            OVER
            (
                PARTITION BY bc.CalendarYear, bc.CalendarMonth
            ) AS WorkingDaysInMonth,

        MAX(CASE WHEN bc.IsWorkingDay = 1 THEN bc.CalendarDate END)
            OVER
            (
                ORDER BY bc.CalendarDate
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ) AS PreviousWorkingDay,

        MIN(CASE WHEN bc.IsWorkingDay = 1 THEN bc.CalendarDate END)
            OVER
            (
                ORDER BY bc.CalendarDate
                ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
            ) AS NextWorkingDay
    FROM BaseCalendar AS bc
)
SELECT
    CalendarDate,
    IsWorkingDay,
    Description,

    CalendarYear,
    CalendarMonth,
    DayOfMonth,
    MonthStartDate,
    MonthEndDate,

    IsoDayOfWeek,
    DayNamePL,
    IsWeekend,
    IsHolidayOrCompanyDayOff,

    FirstWorkingDayOfMonth,
    LastWorkingDayOfMonth,

    CAST
    (
        CASE
            WHEN IsWorkingDay = 1
             AND CalendarDate = FirstWorkingDayOfMonth
                THEN 1
            ELSE 0
        END AS bit
    ) AS IsFirstWorkingDayOfMonth,

    CAST
    (
        CASE
            WHEN IsWorkingDay = 1
             AND CalendarDate = LastWorkingDayOfMonth
                THEN 1
            ELSE 0
        END AS bit
    ) AS IsLastWorkingDayOfMonth,

    CASE
        WHEN IsWorkingDay = 1 THEN WorkingDayNumberInMonth
        ELSE NULL
    END AS WorkingDayNumberInMonth,

    WorkingDaysInMonth,
    PreviousWorkingDay,
    NextWorkingDay,

    CreatedAt,
    ModifiedAt
FROM Calculated;
GO
