USE msdb;
GO

/* ============================================================
   01_create_work_calendar_table.sql

   Cel:
   - Tworzy schemat msdb.dba, jeśli nie istnieje.
   - Tworzy tabelę msdb.dba.WorkCalendar, jeśli nie istnieje.

   Tabela przechowuje:
   - datę,
   - znacznik dnia roboczego,
   - opis dnia,
   - daty utworzenia i modyfikacji wpisu.

   To jest źródło prawdy dla kalendarza.
   Widoki i procedury bazują na tej tabeli.
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

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dba.WorkCalendar', N'U')
          AND name = N'IX_WorkCalendar_IsWorkingDay_CalendarDate'
    )
    BEGIN
        CREATE INDEX IX_WorkCalendar_IsWorkingDay_CalendarDate
            ON dba.WorkCalendar(IsWorkingDay, CalendarDate)
            INCLUDE (Description);
    END;

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
