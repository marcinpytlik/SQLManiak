USE msdb;
GO

/* ============================================================
   02_fill_work_calendar_10_years_poland.sql

   Cel:
   - Wypełnia msdb.dba.WorkCalendar od 1 stycznia bieżącego roku
     do 31 grudnia roku + 10 lat.

   Przykład:
   jeśli dziś jest 2026-06-10, skrypt wypełni zakres:
   2026-01-01 do 2036-12-31

   Uwzględnia:
   - soboty,
   - niedziele,
   - polskie święta stałe,
   - polskie święta ruchome liczone od Wielkanocy,
   - Wigilię 24 grudnia jako dzień wolny od 2025 roku.

   Skrypt jest idempotentny:
   - brakujące dni dodaje,
   - istniejące dni aktualizuje.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF SCHEMA_ID(N'dba') IS NULL
    BEGIN
        EXEC(N'CREATE SCHEMA dba');
    END;

    IF OBJECT_ID(N'dba.WorkCalendar', N'U') IS NULL
    BEGIN
        CREATE TABLE dba.WorkCalendar
        (
            CalendarDate date NOT NULL,
            IsWorkingDay bit NOT NULL,
            Description nvarchar(200) NULL,

            CreatedAt datetime2(0) NOT NULL
                CONSTRAINT DF_WorkCalendar_CreatedAt DEFAULT sysdatetime(),

            ModifiedAt datetime2(0) NULL,

            CONSTRAINT PK_WorkCalendar
                PRIMARY KEY CLUSTERED (CalendarDate)
        );
    END;

    DECLARE @CurrentYear int = YEAR(GETDATE());
    DECLARE @StartDate date = DATEFROMPARTS(@CurrentYear, 1, 1);
    DECLARE @EndDate date = DATEFROMPARTS(@CurrentYear + 10, 12, 31);

    IF OBJECT_ID(N'tempdb..#Calendar', N'U') IS NOT NULL
        DROP TABLE #Calendar;

    CREATE TABLE #Calendar
    (
        CalendarDate date NOT NULL PRIMARY KEY,
        IsWorkingDay bit NOT NULL,
        Description nvarchar(200) NOT NULL
    );

    ;WITH N AS
    (
        SELECT TOP (DATEDIFF(day, @StartDate, @EndDate) + 1)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
        FROM sys.all_objects AS a
        CROSS JOIN sys.all_objects AS b
    )
    INSERT INTO #Calendar
    (
        CalendarDate,
        IsWorkingDay,
        Description
    )
    SELECT
        DATEADD(day, n, @StartDate) AS CalendarDate,
        CASE
            WHEN DATEDIFF(day, '19000101', DATEADD(day, n, @StartDate)) % 7 IN (5, 6)
                THEN 0
            ELSE 1
        END AS IsWorkingDay,
        CASE
            WHEN DATEDIFF(day, '19000101', DATEADD(day, n, @StartDate)) % 7 = 5
                THEN N'Sobota'
            WHEN DATEDIFF(day, '19000101', DATEADD(day, n, @StartDate)) % 7 = 6
                THEN N'Niedziela'
            ELSE N'Dzień roboczy'
        END AS Description
    FROM N;

    IF OBJECT_ID(N'tempdb..#Holidays', N'U') IS NOT NULL
        DROP TABLE #Holidays;

    CREATE TABLE #Holidays
    (
        HolidayDate date NOT NULL PRIMARY KEY,
        HolidayName nvarchar(200) NOT NULL
    );

    DECLARE @Year int = @CurrentYear;

    WHILE @Year <= @CurrentYear + 10
    BEGIN
        --------------------------------------------------------
        -- Algorytm wyliczania Wielkanocy:
        -- Meeus/Jones/Butcher Gregorian algorithm
        --------------------------------------------------------
        DECLARE @a int = @Year % 19;
        DECLARE @b int = @Year / 100;
        DECLARE @c int = @Year % 100;
        DECLARE @d int = @b / 4;
        DECLARE @e int = @b % 4;
        DECLARE @f int = (@b + 8) / 25;
        DECLARE @g int = (@b - @f + 1) / 3;
        DECLARE @h int = (19 * @a + @b - @d - @g + 15) % 30;
        DECLARE @i int = @c / 4;
        DECLARE @k int = @c % 4;
        DECLARE @l int = (32 + 2 * @e + 2 * @i - @h - @k) % 7;
        DECLARE @m int = (@a + 11 * @h + 22 * @l) / 451;
        DECLARE @EasterMonth int = (@h + @l - 7 * @m + 114) / 31;
        DECLARE @EasterDay int = ((@h + @l - 7 * @m + 114) % 31) + 1;

        DECLARE @EasterSunday date =
            DATEFROMPARTS(@Year, @EasterMonth, @EasterDay);

        INSERT INTO #Holidays
        (
            HolidayDate,
            HolidayName
        )
        VALUES
            (DATEFROMPARTS(@Year, 1, 1),   N'Nowy Rok'),
            (DATEFROMPARTS(@Year, 1, 6),   N'Święto Trzech Króli'),
            (DATEFROMPARTS(@Year, 5, 1),   N'Święto Pracy'),
            (DATEFROMPARTS(@Year, 5, 3),   N'Święto Narodowe Trzeciego Maja'),
            (DATEFROMPARTS(@Year, 8, 15),  N'Wniebowzięcie Najświętszej Maryi Panny / Święto Wojska Polskiego'),
            (DATEFROMPARTS(@Year, 11, 1),  N'Wszystkich Świętych'),
            (DATEFROMPARTS(@Year, 11, 11), N'Narodowe Święto Niepodległości'),
            (DATEFROMPARTS(@Year, 12, 24), N'Wigilia Bożego Narodzenia'),
            (DATEFROMPARTS(@Year, 12, 25), N'Boże Narodzenie - pierwszy dzień'),
            (DATEFROMPARTS(@Year, 12, 26), N'Boże Narodzenie - drugi dzień');

        INSERT INTO #Holidays
        (
            HolidayDate,
            HolidayName
        )
        VALUES
            (@EasterSunday, N'Wielkanoc'),
            (DATEADD(day, 1, @EasterSunday),  N'Poniedziałek Wielkanocny'),
            (DATEADD(day, 49, @EasterSunday), N'Zielone Świątki'),
            (DATEADD(day, 60, @EasterSunday), N'Boże Ciało');

        SET @Year += 1;
    END;

    UPDATE c
    SET
        c.IsWorkingDay = 0,
        c.Description = h.HolidayName
    FROM #Calendar AS c
    INNER JOIN #Holidays AS h
        ON h.HolidayDate = c.CalendarDate;

    MERGE dba.WorkCalendar AS target
    USING #Calendar AS source
        ON target.CalendarDate = source.CalendarDate
    WHEN MATCHED THEN
        UPDATE SET
            target.IsWorkingDay = source.IsWorkingDay,
            target.Description = source.Description,
            target.ModifiedAt = sysdatetime()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT
        (
            CalendarDate,
            IsWorkingDay,
            Description
        )
        VALUES
        (
            source.CalendarDate,
            source.IsWorkingDay,
            source.Description
        );

    SELECT
        @StartDate AS StartDate,
        @EndDate AS EndDate,
        COUNT(*) AS TotalDays,
        SUM(CASE WHEN IsWorkingDay = 1 THEN 1 ELSE 0 END) AS WorkingDays,
        SUM(CASE WHEN IsWorkingDay = 0 THEN 1 ELSE 0 END) AS NonWorkingDays
    FROM dba.WorkCalendar
    WHERE CalendarDate BETWEEN @StartDate AND @EndDate;

    SELECT
        YEAR(CalendarDate) AS CalendarYear,
        COUNT(*) AS TotalDays,
        SUM(CASE WHEN IsWorkingDay = 1 THEN 1 ELSE 0 END) AS WorkingDays,
        SUM(CASE WHEN IsWorkingDay = 0 THEN 1 ELSE 0 END) AS NonWorkingDays
    FROM dba.WorkCalendar
    WHERE CalendarDate BETWEEN @StartDate AND @EndDate
    GROUP BY YEAR(CalendarDate)
    ORDER BY CalendarYear;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    DECLARE @ErrorMessage nvarchar(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity int = ERROR_SEVERITY();
    DECLARE @ErrorState int = ERROR_STATE();

    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH;
GO
