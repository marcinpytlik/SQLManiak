USE msdb;
GO

/* ============================================================
   04_create_work_calendar_check_procedures.sql

   Cel:
   - Tworzy procedury pomocnicze dla SQL Agent Jobów.

   Procedury:
   1. dba.usp_CheckWorkCalendarForSqlAgent
      - podstawowe sprawdzanie: roboczy/wolny/brak wpisu

   2. dba.usp_CheckWorkCalendarRuleForSqlAgent
      - sprawdzanie reguł:
        ANY_WORKING_DAY
        FIRST_WORKING_DAY_OF_MONTH
        LAST_WORKING_DAY_OF_MONTH
        NTH_WORKING_DAY_OF_MONTH
   ============================================================ */

CREATE OR ALTER PROCEDURE dba.usp_CheckWorkCalendarForSqlAgent
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today date = CONVERT(date, GETDATE());
    DECLARE @IsWorkingDay bit;
    DECLARE @Description nvarchar(200);

    SELECT
        @IsWorkingDay = IsWorkingDay,
        @Description = Description
    FROM dba.WorkCalendar
    WHERE CalendarDate = @Today;

    IF @IsWorkingDay IS NULL
    BEGIN
        PRINT 'ERROR: Brak wpisu w msdb.dba.WorkCalendar dla dzisiejszej daty.';
        PRINT CONCAT('Data: ', CONVERT(varchar(10), @Today, 120));

        RETURN 99;
    END;

    IF @IsWorkingDay = 0
    BEGIN
        PRINT 'INFO: Dzisiaj jest dzień wolny.';
        PRINT CONCAT('Data: ', CONVERT(varchar(10), @Today, 120));
        PRINT CONCAT('Opis: ', ISNULL(@Description, N'brak opisu'));

        RETURN 10;
    END;

    PRINT 'INFO: Dzisiaj jest dzień roboczy.';
    PRINT CONCAT('Data: ', CONVERT(varchar(10), @Today, 120));
    PRINT CONCAT('Opis: ', ISNULL(@Description, N'brak opisu'));

    RETURN 0;
END;
GO

CREATE OR ALTER PROCEDURE dba.usp_CheckWorkCalendarRuleForSqlAgent
(
    @RuleName sysname = N'ANY_WORKING_DAY',
    @WorkingDayNumberInMonth int = NULL,
    @CheckDate date = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Kody zwrotne:
        0  = reguła spełniona, job może iść dalej
        10 = reguła niespełniona, job ma zakończyć się kontrolowanie jako sukces
        99 = błąd konfiguracji, brak daty albo zła reguła
    */

    DECLARE @DateToCheck date = ISNULL(@CheckDate, CONVERT(date, GETDATE()));

    DECLARE
        @IsWorkingDay bit,
        @IsFirstWorkingDayOfMonth bit,
        @IsLastWorkingDayOfMonth bit,
        @CurrentWorkingDayNumberInMonth int,
        @Description nvarchar(200);

    SELECT
        @IsWorkingDay = IsWorkingDay,
        @IsFirstWorkingDayOfMonth = IsFirstWorkingDayOfMonth,
        @IsLastWorkingDayOfMonth = IsLastWorkingDayOfMonth,
        @CurrentWorkingDayNumberInMonth = WorkingDayNumberInMonth,
        @Description = Description
    FROM dba.vWorkCalendarEnriched
    WHERE CalendarDate = @DateToCheck;

    IF @IsWorkingDay IS NULL
    BEGIN
        PRINT CONCAT('ERROR: Brak wpisu w msdb.dba.WorkCalendar dla daty: ', CONVERT(varchar(10), @DateToCheck, 120));
        RETURN 99;
    END;

    IF @RuleName NOT IN
    (
        N'ANY_WORKING_DAY',
        N'FIRST_WORKING_DAY_OF_MONTH',
        N'LAST_WORKING_DAY_OF_MONTH',
        N'NTH_WORKING_DAY_OF_MONTH'
    )
    BEGIN
        PRINT CONCAT('ERROR: Nieobsługiwana reguła: ', @RuleName);
        RETURN 99;
    END;

    IF @RuleName = N'ANY_WORKING_DAY'
    BEGIN
        IF @IsWorkingDay = 1
        BEGIN
            PRINT 'INFO: Reguła ANY_WORKING_DAY spełniona.';
            RETURN 0;
        END;

        PRINT CONCAT('INFO: Reguła ANY_WORKING_DAY niespełniona. Opis: ', ISNULL(@Description, N'brak opisu'));
        RETURN 10;
    END;

    IF @RuleName = N'FIRST_WORKING_DAY_OF_MONTH'
    BEGIN
        IF @IsFirstWorkingDayOfMonth = 1
        BEGIN
            PRINT 'INFO: Reguła FIRST_WORKING_DAY_OF_MONTH spełniona.';
            RETURN 0;
        END;

        PRINT 'INFO: To nie jest pierwszy dzień roboczy miesiąca.';
        RETURN 10;
    END;

    IF @RuleName = N'LAST_WORKING_DAY_OF_MONTH'
    BEGIN
        IF @IsLastWorkingDayOfMonth = 1
        BEGIN
            PRINT 'INFO: Reguła LAST_WORKING_DAY_OF_MONTH spełniona.';
            RETURN 0;
        END;

        PRINT 'INFO: To nie jest ostatni dzień roboczy miesiąca.';
        RETURN 10;
    END;

    IF @RuleName = N'NTH_WORKING_DAY_OF_MONTH'
    BEGIN
        IF @WorkingDayNumberInMonth IS NULL OR @WorkingDayNumberInMonth < 1
        BEGIN
            PRINT 'ERROR: Dla reguły NTH_WORKING_DAY_OF_MONTH parametr @WorkingDayNumberInMonth musi być większy od zera.';
            RETURN 99;
        END;

        IF @IsWorkingDay = 1
           AND @CurrentWorkingDayNumberInMonth = @WorkingDayNumberInMonth
        BEGIN
            PRINT CONCAT('INFO: Reguła NTH_WORKING_DAY_OF_MONTH spełniona. Numer dnia roboczego: ', @WorkingDayNumberInMonth);
            RETURN 0;
        END;

        PRINT CONCAT('INFO: To nie jest ', @WorkingDayNumberInMonth, '. dzień roboczy miesiąca.');
        RETURN 10;
    END;

    RETURN 99;
END;
GO
