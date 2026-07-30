USE [master]
GO
ALTER DATABASE [DBACentralRepository] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
USE [master]
GO
/****** Object:  Database [DBACentralRepository]    Script Date: 30.07.2026 08:07:16 ******/
DROP DATABASE [DBACentralRepository]
GO
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'DBACentralRepository'
GO

USE master;
GO

IF DB_ID(N'DBACentralRepository') IS NULL
    CREATE DATABASE DBACentralRepository;
GO

ALTER DATABASE DBACentralRepository SET RECOVERY SIMPLE;
GO

USE DBACentralRepository;
GO

DECLARE @Schemas TABLE
(
    SchemaName sysname NOT NULL,
    Description nvarchar(4000) NOT NULL
);

INSERT @Schemas(SchemaName, Description)
VALUES
(N'job', N'Konfiguracja SQL Server Agent, kroki, harmonogramy, historia wykonań oraz powiązania jobów z bazami.'),
(N'db', N'Inwentaryzacja baz danych, plików, ustawień i największych obiektów.'),
(N'backup', N'Historia backupów, polityki RPO, pliki backupowe i testy restore.'),
(N'capacity', N'Historia pojemności wolumenów, baz i plików oraz prognozowanie wzrostu.'),
(N'ha', N'Stan Availability Groups, replik, baz w AG i historia failoverów.'),
(N'maintenance', N'Historia CHECKDB, suspect_pages, indeksów i statystyk.'),
(N'patch', N'Historia buildów SQL Server, katalog CU/GDR i ocena zgodności patchowania.'),
(N'config', N'Konfiguracja instancji, tempdb, trace flags, linked servers i baseline.'),
(N'security', N'Loginy, role, uprawnienia, proxy, credentials i Database Mail.'),
(N'audit', N'Audyt zgodności, dokumentacja, wyjątki i historia zmian.'),
(N'alert', N'Centralne reguły i findingi operacyjne.'),
(N'report', N'Widoki i procedury raportowe dla DBA i Confluence.');

DECLARE @SchemaName sysname, @Description nvarchar(4000), @Sql nvarchar(max);

DECLARE c CURSOR LOCAL FAST_FORWARD FOR
SELECT SchemaName, Description FROM @Schemas;

OPEN c;
FETCH NEXT FROM c INTO @SchemaName, @Description;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = @SchemaName)
    BEGIN
        SET @Sql = N'CREATE SCHEMA ' + QUOTENAME(@SchemaName) + N' AUTHORIZATION dbo;';
        EXEC sys.sp_executesql @Sql;
    END;

    IF EXISTS
    (
        SELECT 1 FROM sys.extended_properties
        WHERE class = 3
          AND major_id = SCHEMA_ID(@SchemaName)
          AND name = N'MS_Description'
    )
        EXEC sys.sp_updateextendedproperty
            @name=N'MS_Description', @value=@Description,
            @level0type=N'SCHEMA', @level0name=@SchemaName;
    ELSE
        EXEC sys.sp_addextendedproperty
            @name=N'MS_Description', @value=@Description,
            @level0type=N'SCHEMA', @level0name=@SchemaName;

    FETCH NEXT FROM c INTO @SchemaName, @Description;
END

CLOSE c;
DEALLOCATE c;
GO
