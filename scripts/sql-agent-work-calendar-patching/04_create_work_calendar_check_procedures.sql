USE msdb;
GO

/* ============================================================
   04_create_work_calendar_check_procedures.sql

   Cel:
   - Tworzy procedury pomocnicze dla SQL Agent Jobów.

   Procedury:
   1. dba.usp_CheckWorkCalendarForSqlAgent
   2. dba.usp_CheckWorkCalendarRuleForSqlAgent

   Kody zwrotne:
   0  = reguła spełniona / dzień roboczy
   10 = reguła niespełniona / dzień wolny
   99 = błąd konfiguracji, brak daty albo zła reguła
   ============================================================ */

CREATE OR ALTER PROCEDURE dba.usp_CheckWorkCalendarForSqlAgent
(
    @CheckDate date = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DateToCheck date = ISNULL(@CheckDate, CONVERT(date, GETDATE()));
    DECLARE @IsWorkingDay bit;
    DECLARE @Description nvarchar(200);

    SELECT
        @IsWorkingDay = IsWorkingDay,
        @Description = Description
    FROM dba.WorkCalendar
    WHERE CalendarDate = @DateToCheck;

    IF @IsWorkingDay IS NULL
    BEGIN
        PRINT CONCAT('ERROR: Brak wpisu w msdb.dba.WorkCalendar dla daty: ', CONVERT(varchar(10), @DateToCheck, 120));
        RETURN 99;
    END;

    IF @IsWorkingDay = 0
    BEGIN
        PRINT 'INFO: Sprawdzana data jest dniem wolnym.';
        PRINT CONCAT('Data: ', CONVERT(varchar(10), @DateToCheck, 120));
        PRINT CONCAT('Opis: ', ISNULL(@Description, N'brak opisu'));
        RETURN 10;
    END;

    PRINT 'INFO: Sprawdzana data jest dniem roboczym.';
    PRINT CONCAT('Data: ', CONVERT(varchar(10), @DateToCheck, 120));
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

    DECLARE @DateToCheck date = ISNULL(@CheckDate, CONVERT(date, GETDATE()));
    DECLARE @NormalizedRuleName sysname = UPPER(LTRIM(RTRIM(ISNULL(@RuleName, N''))));

    DECLARE
        @IsWorkingDay bit,
        @IsFirstWorkingDayOfMonth bit,
        @IsLastWorkingDayOfMonth bit,
        @CurrentWorkingDayNumberInMonth int,
        @WorkingDaysInMonth int,
        @Description nvarchar(200);

    SELECT
        @IsWorkingDay = IsWorkingDay,
        @IsFirstWorkingDayOfMonth = IsFirstWorkingDayOfMonth,
        @IsLastWorkingDayOfMonth = IsLastWorkingDayOfMonth,
        @CurrentWorkingDayNumberInMonth = WorkingDayNumberInMonth,
        @WorkingDaysInMonth = WorkingDaysInMonth,
        @Description = Description
    FROM dba.vWorkCalendarEnriched
    WHERE CalendarDate = @DateToCheck;

    IF @IsWorkingDay IS NULL
    BEGIN
        PRINT CONCAT('ERROR: Brak wpisu w msdb.dba.WorkCalendar dla daty: ', CONVERT(varchar(10), @DateToCheck, 120));
        RETURN 99;
    END;

    IF @NormalizedRuleName NOT IN
    (
        N'ANY_WORKING_DAY',
        N'FIRST_WORKING_DAY_OF_MONTH',
        N'LAST_WORKING_DAY_OF_MONTH',
        N'NTH_WORKING_DAY_OF_MONTH'
    )
    BEGIN
        PRINT CONCAT('ERROR: Nieobsługiwana reguła: ', ISNULL(@RuleName, N'<NULL>'));
        RETURN 99;
    END;

    IF @NormalizedRuleName = N'ANY_WORKING_DAY'
    BEGIN
        IF @IsWorkingDay = 1
        BEGIN
            PRINT CONCAT('INFO: Reguła ANY_WORKING_DAY spełniona. Data: ', CONVERT(varchar(10), @DateToCheck, 120));
            RETURN 0;
        END;

        PRINT CONCAT('INFO: Reguła ANY_WORKING_DAY niespełniona. Data: ', CONVERT(varchar(10), @DateToCheck, 120), '. Opis: ', ISNULL(@Description, N'brak opisu'));
        RETURN 10;
    END;

    IF @NormalizedRuleName = N'FIRST_WORKING_DAY_OF_MONTH'
    BEGIN
        IF @IsFirstWorkingDayOfMonth = 1
        BEGIN
            PRINT CONCAT('INFO: Reguła FIRST_WORKING_DAY_OF_MONTH spełniona. Data: ', CONVERT(varchar(10), @DateToCheck, 120));
            RETURN 0;
        END;

        PRINT CONCAT('INFO: To nie jest pierwszy dzień roboczy miesiąca. Data: ', CONVERT(varchar(10), @DateToCheck, 120));
        RETURN 10;
    END;

    IF @NormalizedRuleName = N'LAST_WORKING_DAY_OF_MONTH'
    BEGIN
        IF @IsLastWorkingDayOfMonth = 1
        BEGIN
            PRINT CONCAT('INFO: Reguła LAST_WORKING_DAY_OF_MONTH spełniona. Data: ', CONVERT(varchar(10), @DateToCheck, 120));
            RETURN 0;
        END;

        PRINT CONCAT('INFO: To nie jest ostatni dzień roboczy miesiąca. Data: ', CONVERT(varchar(10), @DateToCheck, 120));
        RETURN 10;
    END;

    IF @NormalizedRuleName = N'NTH_WORKING_DAY_OF_MONTH'
    BEGIN
        IF @WorkingDayNumberInMonth IS NULL OR @WorkingDayNumberInMonth < 1
        BEGIN
            PRINT 'ERROR: Dla reguły NTH_WORKING_DAY_OF_MONTH parametr @WorkingDayNumberInMonth musi być większy od zera.';
            RETURN 99;
        END;

        IF @WorkingDayNumberInMonth > ISNULL(@WorkingDaysInMonth, 0)
        BEGIN
            PRINT CONCAT('ERROR: Parametr @WorkingDayNumberInMonth jest większy niż liczba dni roboczych w miesiącu. Parametr: ', @WorkingDayNumberInMonth, ', liczba dni roboczych: ', ISNULL(@WorkingDaysInMonth, 0));
            RETURN 99;
        END;

        IF @IsWorkingDay = 1
           AND @CurrentWorkingDayNumberInMonth = @WorkingDayNumberInMonth
        BEGIN
            PRINT CONCAT('INFO: Reguła NTH_WORKING_DAY_OF_MONTH spełniona. Numer dnia roboczego: ', @WorkingDayNumberInMonth);
            RETURN 0;
        END;

        PRINT CONCAT('INFO: To nie jest ', @WorkingDayNumberInMonth, '. dzień roboczy miesiąca. Data: ', CONVERT(varchar(10), @DateToCheck, 120));
        RETURN 10;
    END;

    RETURN 99;
END;
GO

-- Weryfikacja podstawowa
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N'ANY_WORKING_DAY';

SELECT @ReturnCode AS ReturnCodeAnyWorkingDay;
GO

DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N'LAST_WORKING_DAY_OF_MONTH';

SELECT @ReturnCode AS ReturnCodeLastWorkingDayOfMonth;
GO

DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N'NTH_WORKING_DAY_OF_MONTH',
    @WorkingDayNumberInMonth = 3;

SELECT @ReturnCode AS ReturnCodeThirdWorkingDayOfMonth;
GO
