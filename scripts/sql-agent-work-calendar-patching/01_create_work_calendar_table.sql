USE msdb;
GO

/* ============================================================
   01_create_work_calendar_table.sql

   Cel:
   - Tworzy schemat msdb.dba, jeśli nie istnieje.
   - Tworzy tabelę msdb.dba.WorkCalendar, jeśli nie istnieje.
   - Dostosowuje istniejącą tabelę do wersji poprawionej.

   Poprawki w tej wersji:
   - Dodano IsManualOverride, żeby ręcznie ustawione dni firmowo wolne
     nie były nadpisywane przez ponowne uruchomienie skryptu 02.
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
            IsManualOverride bit NOT NULL
                CONSTRAINT DF_WorkCalendar_IsManualOverride DEFAULT (0),

            CreatedAt datetime2(0) NOT NULL
                CONSTRAINT DF_WorkCalendar_CreatedAt DEFAULT sysdatetime(),

            ModifiedAt datetime2(0) NULL,

            CONSTRAINT PK_WorkCalendar
                PRIMARY KEY CLUSTERED (CalendarDate)
        );
    END;

    IF COL_LENGTH(N'dba.WorkCalendar', N'IsManualOverride') IS NULL
    BEGIN
        ALTER TABLE dba.WorkCalendar
        ADD IsManualOverride bit NOT NULL
            CONSTRAINT DF_WorkCalendar_IsManualOverride DEFAULT (0);
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
            INCLUDE (Description, IsManualOverride);
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

-- Weryfikacja
SELECT
    s.name AS SchemaName,
    t.name AS TableName
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = N'dba'
  AND t.name = N'WorkCalendar';
GO

SELECT
    c.name AS ColumnName,
    ty.name AS DataType,
    c.is_nullable
FROM sys.columns AS c
INNER JOIN sys.types AS ty
    ON ty.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID(N'dba.WorkCalendar', N'U')
ORDER BY c.column_id;
GO
