:setvar DbName "YourDB"

/* Test dymny: tworzy user/rolę i wykonuje GRANT */
IF DB_ID('$(DbName)') IS NULL
BEGIN
    RAISERROR('Database $(DbName) does not exist.', 16, 1);
    RETURN;
END
GO

DECLARE @sql nvarchar(max) = N'
USE [' + REPLACE('$(DbName)',']',']]') + N'];

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N''TestUser'')
    CREATE USER [TestUser] WITHOUT LOGIN;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N''rTest'')
    CREATE ROLE [rTest];

ALTER ROLE [rTest] ADD MEMBER [TestUser];

DECLARE @obj sysname =
    (SELECT TOP (1) QUOTENAME(OBJECT_SCHEMA_NAME(object_id)) + ''.'' + QUOTENAME(name)
     FROM sys.objects WHERE type IN (''U'',''V'') ORDER BY object_id);
IF @obj IS NULL
BEGIN
    -- tworzymy prostą tabelę testową
    CREATE TABLE dbo._AuditTest(Id int identity primary key, Txt nvarchar(50));
    SET @obj = ''[dbo].[_AuditTest]'';
END

EXEC (''GRANT SELECT ON '' + @obj + '' TO [rTest]'');';

EXEC (@sql);
PRINT 'Smoke test executed in [' + '$(DbName)' + '].';
