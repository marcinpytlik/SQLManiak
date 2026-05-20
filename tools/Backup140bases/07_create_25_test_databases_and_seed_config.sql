/*
    07_create_25_test_databases_and_seed_config.sql

    Cel:
      - utworzyć 20-25 testowych baz danych,
      - ustawić recovery model FULL,
      - dodać przykładową tabelę z danymi w każdej bazie,
      - dopisać bazy do msdb.dbo.DBA_BackupDatabaseConfig,
      - rozdzielić backupy między X:\backup i Z:\backup.

    Wymagania:
      - wcześniej uruchom 01_create_backup_config_tables.sql,
      - uruchamiaj na instancji testowej, np. syriusz,
      - konto SQL Server Engine musi mieć prawa do X:\backup i Z:\backup,
      - skrypt tworzy bazy w domyślnych lokalizacjach danych/logów instancji.

    Uruchomienie:
      sqlcmd -S "syriusz" -E -i .\07_create_25_test_databases_and_seed_config.sql
*/

USE [master];
GO

SET NOCOUNT ON;
GO

DECLARE
    @DatabasePrefix sysname = N'DBA_BCK_TEST_',
    @DatabaseCount  int     = 25,
    @SplitAfter     int     = 13,
    @BackupPathX    nvarchar(4000) = N'X:\backup',
    @BackupPathZ    nvarchar(4000) = N'Z:\backup';

IF @DatabaseCount < 1 OR @DatabaseCount > 200
BEGIN
    THROW 51000, 'Nieprawidłowa liczba baz testowych. Ustaw @DatabaseCount w zakresie 1-200.', 1;
END;

IF OBJECT_ID(N'msdb.dbo.DBA_BackupDatabaseConfig', N'U') IS NULL
BEGIN
    THROW 51001, 'Brakuje tabeli msdb.dbo.DBA_BackupDatabaseConfig. Najpierw uruchom 01_create_backup_config_tables.sql.', 1;
END;

DECLARE
    @i int = 1,
    @DbName sysname,
    @Sql nvarchar(max),
    @BackupPath nvarchar(4000),
    @Notes nvarchar(1000),
    @Priority int;

WHILE @i <= @DatabaseCount
BEGIN
    SET @DbName = @DatabasePrefix + RIGHT('000' + CONVERT(varchar(10), @i), 3);
    SET @BackupPath = CASE WHEN @i <= @SplitAfter THEN @BackupPathX ELSE @BackupPathZ END;
    SET @Priority = CASE WHEN @i <= @SplitAfter THEN 10 ELSE 20 END;
    SET @Notes = CASE WHEN @i <= @SplitAfter THEN N'Lab backup group X' ELSE N'Lab backup group Z' END;

    IF DB_ID(@DbName) IS NULL
    BEGIN
        SET @Sql = N'CREATE DATABASE ' + QUOTENAME(@DbName) + N';';
        EXEC sys.sp_executesql @Sql;
        PRINT CONCAT('Created database: ', @DbName);
    END
    ELSE
    BEGIN
        PRINT CONCAT('Database already exists: ', @DbName);
    END;

    SET @Sql = N'
ALTER DATABASE ' + QUOTENAME(@DbName) + N' SET RECOVERY FULL WITH NO_WAIT;

USE ' + QUOTENAME(@DbName) + N';

IF OBJECT_ID(N''dbo.BackupTestData'', N''U'') IS NULL
BEGIN
    CREATE TABLE dbo.BackupTestData
    (
        Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_BackupTestData PRIMARY KEY,
        CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_BackupTestData_CreatedAt DEFAULT (SYSDATETIME()),
        Payload nvarchar(4000) NOT NULL
    );
END;

INSERT INTO dbo.BackupTestData(Payload)
SELECT TOP (100)
    CONCAT(N''Test data for database '', DB_NAME(), N'' row '', ROW_NUMBER() OVER (ORDER BY (SELECT NULL)))
FROM sys.all_objects;
';
    EXEC sys.sp_executesql @Sql;

    MERGE msdb.dbo.DBA_BackupDatabaseConfig AS target
    USING
    (
        SELECT
            @DbName     AS DatabaseName,
            @BackupPath AS BackupBasePath,
            CAST(1 AS bit) AS IsEnabled,
            CAST(1 AS bit) AS BackupFull,
            CAST(1 AS bit) AS BackupDiff,
            CAST(1 AS bit) AS BackupLog,
            @Priority AS Priority,
            @Notes AS Notes
    ) AS source
        ON target.DatabaseName = source.DatabaseName
    WHEN MATCHED THEN
        UPDATE SET
            BackupBasePath = source.BackupBasePath,
            IsEnabled = source.IsEnabled,
            BackupFull = source.BackupFull,
            BackupDiff = source.BackupDiff,
            BackupLog = source.BackupLog,
            Priority = source.Priority,
            Notes = source.Notes
    WHEN NOT MATCHED THEN
        INSERT
        (
            DatabaseName,
            BackupBasePath,
            IsEnabled,
            BackupFull,
            BackupDiff,
            BackupLog,
            Priority,
            Notes
        )
        VALUES
        (
            source.DatabaseName,
            source.BackupBasePath,
            source.IsEnabled,
            source.BackupFull,
            source.BackupDiff,
            source.BackupLog,
            source.Priority,
            source.Notes
        );

    SET @i += 1;
END;
GO

PRINT '=== Test databases created and added to msdb.dbo.DBA_BackupDatabaseConfig ===';
GO

SELECT
    DatabaseName,
    BackupBasePath,
    IsEnabled,
    BackupFull,
    BackupDiff,
    BackupLog,
    Priority,
    Notes
FROM msdb.dbo.DBA_BackupDatabaseConfig
WHERE DatabaseName LIKE N'DBA_BCK_TEST[_]%'
ORDER BY DatabaseName;
GO

/*
    Opcjonalny test planu backupu bez wykonywania backupów,
    jeśli procedura z paczki obsługuje @DryRun = 1.
*/
EXEC msdb.dbo.usp_BackupDatabases_ByConfig
    @BackupType = 'FULL',
    @DryRun = 1;
GO
