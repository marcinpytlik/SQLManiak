/* Fix_Orphaned_Users_AllDB.sql — mapuje users -> logins po nazwie/SID */
SET NOCOUNT ON;

DECLARE @db sysname, @sql nvarchar(max);

DECLARE dbs CURSOR LOCAL FAST_FORWARD FOR
SELECT name
FROM sys.databases
WHERE database_id > 4 AND state = 0;

OPEN dbs;
FETCH NEXT FROM dbs INTO @db;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';
    -- Raport osieroconych
    SELECT DB_NAME() AS DatabaseName, dp.name AS UserName, dp.type_desc, dp.sid
    FROM sys.database_principals AS dp
    LEFT JOIN sys.server_principals  AS sp ON dp.sid = sp.sid
    WHERE dp.type IN (''S'',''U'')
      AND dp.sid IS NOT NULL
      AND dp.name NOT IN (''dbo'',''guest'',''INFORMATION_SCHEMA'',''sys'')
      AND sp.sid IS NULL;

    -- Automapowanie po nazwie (jeśli istnieje login o tej samej nazwie)
    DECLARE @u sysname, @map nvarchar(400);
    DECLARE ucur CURSOR LOCAL FAST_FORWARD FOR
        SELECT dp.name
        FROM sys.database_principals AS dp
        LEFT JOIN sys.server_principals AS sp ON dp.sid = sp.sid
        WHERE dp.type IN (''S'',''U'')
          AND dp.sid IS NOT NULL
          AND dp.name NOT IN (''dbo'',''guest'',''INFORMATION_SCHEMA'',''sys'')
          AND sp.sid IS NULL
          AND EXISTS (SELECT 1 FROM sys.server_principals WHERE name = dp.name);

    OPEN ucur;
    FETCH NEXT FROM ucur INTO @u;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            SET @map = N''ALTER USER '' + QUOTENAME(@u) + N'' WITH LOGIN = '' + QUOTENAME(@u) + N'';'';
            EXEC (@map);
            PRINT N''[OK] '' + DB_NAME() + N'': '' + @map;
        END TRY
        BEGIN CATCH
            PRINT N''[WARN] '' + DB_NAME() + N'': '' + ERROR_MESSAGE();
        END CATCH;
        FETCH NEXT FROM ucur INTO @u;
    END
    CLOSE ucur; DEALLOCATE ucur;';
    EXEC sys.sp_executesql @sql;

    FETCH NEXT FROM dbs INTO @db;
END
CLOSE dbs; DEALLOCATE dbs;
