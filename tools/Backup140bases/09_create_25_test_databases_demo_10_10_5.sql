/*
    09_create_25_test_databases_demo_10_10_5.sql

    Cel pokazu:
      - utworzyć 25 testowych baz danych,
      - przypisać 10 baz do C:\backup1,
      - przypisać 10 baz do C:\backup2,
      - przypisać 5 baz do C:\backup3,
      - dopisać/zaaktualizować konfigurację w msdb.dbo.DBA_BackupDatabaseConfig,
      - pokazać DryRun oraz gotowość do realnego backupu.

    Wymagania:
      - wcześniej uruchom:
          01_create_backup_config_tables.sql
          02_create_backup_procedure_by_config.sql
      - konto usługi SQL Server Engine musi mieć prawo zapisu do:
          C:\backup1
          C:\backup2
          C:\backup3

    Uruchomienie:
      sqlcmd -S "syriusz" -E -i .\09_create_25_test_databases_demo_10_10_5.sql
*/

USE [master];
GO

SET NOCOUNT ON;
GO

DECLARE
    @DatabasePrefix sysname = N'DBA_BCK_TEST_',
    @DatabaseCount  int     = 25,
    @BackupPath1    nvarchar(4000) = N'C:\backup1',
    @BackupPath2    nvarchar(4000) = N'C:\backup2',
    @BackupPath3    nvarchar(4000) = N'C:\backup3';

IF OBJECT_ID(N'msdb.dbo.DBA_BackupDatabaseConfig', N'U') IS NULL
BEGIN
    THROW 51001, 'Brakuje tabeli msdb.dbo.DBA_BackupDatabaseConfig. Najpierw uruchom 01_create_backup_config_tables.sql.', 1;
END;

IF OBJECT_ID(N'msdb.dbo.usp_BackupDatabases_ByConfig', N'P') IS NULL
BEGIN
    THROW 51002, 'Brakuje procedury msdb.dbo.usp_BackupDatabases_ByConfig. Najpierw uruchom 02_create_backup_procedure_by_config.sql.', 1;
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

    SET @BackupPath =
        CASE
            WHEN @i BETWEEN 1 AND 10 THEN @BackupPath1
            WHEN @i BETWEEN 11 AND 20 THEN @BackupPath2
            ELSE @BackupPath3
        END;

    SET @Priority =
        CASE
            WHEN @i BETWEEN 1 AND 10 THEN 10
            WHEN @i BETWEEN 11 AND 20 THEN 20
            ELSE 30
        END;

    SET @Notes =
        CASE
            WHEN @i BETWEEN 1 AND 10 THEN N'Lab demo group: C:\backup1'
            WHEN @i BETWEEN 11 AND 20 THEN N'Lab demo group: C:\backup2'
            ELSE N'Lab demo group: C:\backup3'
        END;

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

PRINT '=== Demo 10/10/5: konfiguracja baz testowych ===';
GO

SELECT
    BackupBasePath,
    COUNT(*) AS DatabaseCount
FROM msdb.dbo.DBA_BackupDatabaseConfig
WHERE DatabaseName LIKE N'DBA_BCK_TEST[_]%'
GROUP BY BackupBasePath
ORDER BY BackupBasePath;
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

PRINT '=== DryRun: procedura pokaże plan FULL backupu bez wykonywania kopii ===';
GO

EXEC msdb.dbo.usp_BackupDatabases_ByConfig
    @BackupType = 'FULL',
    @DryRun = 1;
GO
