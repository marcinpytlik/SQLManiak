/* DBACentralRepositoryv4 — isolated bootstrap. Run manually in LAB first. */
USE [master];
GO
IF DB_ID(N'DBACentralRepositoryv4') IS NULL
BEGIN
    CREATE DATABASE [DBACentralRepositoryv4];
END;
GO
USE [DBACentralRepositoryv4];
GO
DECLARE @name sysname, @sql nvarchar(max);
DECLARE schema_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT v.SchemaName FROM (VALUES (N'inventory'), (N'patch'), (N'audit'), (N'report'), (N'config')) v(SchemaName);
OPEN schema_cursor;
FETCH NEXT FROM schema_cursor INTO @name;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF SCHEMA_ID(@name) IS NULL
    BEGIN
        SET @sql = N'CREATE SCHEMA ' + QUOTENAME(@name) + N' AUTHORIZATION dbo;';
        EXEC sys.sp_executesql @sql;
    END;
    FETCH NEXT FROM schema_cursor INTO @name;
END;
CLOSE schema_cursor;
DEALLOCATE schema_cursor;
GO
