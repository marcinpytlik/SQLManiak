/*
    08_cleanup_25_test_databases_and_config.sql

    Cel:
      - usunąć wpisy testowych baz z msdb.dbo.DBA_BackupDatabaseConfig,
      - usunąć testowe bazy DBA_BCK_TEST_001 ... DBA_BCK_TEST_025.

    UWAGA:
      - uruchamiaj tylko w labie/testach,
      - skrypt usuwa bazy danych.

    Uruchomienie:
      sqlcmd -S "syriusz" -E -i .\08_cleanup_25_test_databases_and_config.sql
*/

USE [master];
GO

SET NOCOUNT ON;
GO

DECLARE
    @DatabasePrefix sysname = N'DBA_BCK_TEST_',
    @DatabaseCount  int     = 25,
    @i int = 1,
    @DbName sysname,
    @Sql nvarchar(max);

IF OBJECT_ID(N'msdb.dbo.DBA_BackupDatabaseConfig', N'U') IS NOT NULL
BEGIN
    DELETE FROM msdb.dbo.DBA_BackupDatabaseConfig
    WHERE DatabaseName LIKE N'DBA_BCK_TEST[_]%';
END;

WHILE @i <= @DatabaseCount
BEGIN
    SET @DbName = @DatabasePrefix + RIGHT('000' + CONVERT(varchar(10), @i), 3);

    IF DB_ID(@DbName) IS NOT NULL
    BEGIN
        SET @Sql = N'
ALTER DATABASE ' + QUOTENAME(@DbName) + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE ' + QUOTENAME(@DbName) + N';';
        EXEC sys.sp_executesql @Sql;
        PRINT CONCAT('Dropped database: ', @DbName);
    END;

    SET @i += 1;
END;
GO

PRINT '=== Cleanup completed ===';
GO
