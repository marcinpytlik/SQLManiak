
USE master;
GO

SET NOCOUNT ON;

------------------------------------------------------------
-- KONFIGURACJA
------------------------------------------------------------
DECLARE @LoginName sysname = N'DOMENA\Konto';
DECLARE @Execute bit = 0; -- 0 = DRY RUN, 1 = EXECUTE

------------------------------------------------------------
-- ZMIENNE
------------------------------------------------------------
DECLARE @DatabaseName sysname;
DECLARE @SQL nvarchar(max);
DECLARE @LoginType char(1);

------------------------------------------------------------
-- WALIDACJA LOGINU
------------------------------------------------------------
SELECT @LoginType = [type]
FROM sys.server_principals
WHERE name = @LoginName
  AND [type] IN ('S', 'U', 'G');

IF @LoginType IS NULL
BEGIN
    RAISERROR(
        'Login nie istnieje na instancji lub ma nieobslugiwany typ.',
        16, 1
    );
    RETURN;
END;

------------------------------------------------------------
-- TABELA WYNIKOW
------------------------------------------------------------
CREATE TABLE #Results
(
    DatabaseName sysname,
    Status nvarchar(30),
    Details nvarchar(max)
);

------------------------------------------------------------
-- KURSOR PO BAZACH
------------------------------------------------------------
DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT name
FROM sys.databases
WHERE database_id > 4
  AND state_desc = 'ONLINE'
  AND is_read_only = 0
  AND source_database_id IS NULL
  AND user_access_desc = 'MULTI_USER'
  AND HAS_DBACCESS(name) = 1
ORDER BY name;

OPEN db_cursor;

FETCH NEXT FROM db_cursor INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'
USE ' + QUOTENAME(@DatabaseName) + N';

DECLARE @UserName sysname;
DECLARE @IsMember bit = 0;

-- Znajdz istniejacego uzytkownika
-- powiazanego z SID loginu.
SELECT @UserName = dp.name
FROM sys.database_principals AS dp
WHERE dp.sid = SUSER_SID(@LoginName)
  AND dp.type IN (''S'', ''U'', ''G'');

-- Nie tworz drugiego uzytkownika dla tego samego loginu.
IF @UserName IS NULL
BEGIN
    SET @UserName = @LoginName;

    IF DATABASE_PRINCIPAL_ID(@UserName) IS NOT NULL
    BEGIN
        THROW 50001,
            ''Nazwa uzytkownika jest juz zajeta przez inny principal.'',
            1;
    END;

    IF @Execute = 1
    BEGIN
        EXEC(
            N''CREATE USER ''
            + QUOTENAME(@UserName)
            + N'' FOR LOGIN ''
            + QUOTENAME(@LoginName)
        );
    END;
END;

-- Sprawdz bezposrednie czlonkostwo w db_owner.
SELECT @IsMember = 1
FROM sys.database_role_members AS drm
JOIN sys.database_principals AS r
    ON r.principal_id = drm.role_principal_id
JOIN sys.database_principals AS m
    ON m.principal_id = drm.member_principal_id
WHERE r.name = N''db_owner''
  AND m.name = @UserName;

IF @IsMember = 1
BEGIN
    INSERT INTO #Results
    VALUES (DB_NAME(), N''ALREADY_MEMBER'',
            N''Uzytkownik jest juz w db_owner'');
END
ELSE
BEGIN
    IF @Execute = 1
    BEGIN
        EXEC(
            N''ALTER ROLE [db_owner] ADD MEMBER ''
            + QUOTENAME(@UserName)
        );

        INSERT INTO #Results
        VALUES (DB_NAME(), N''ADDED'',
                N''Dodano uzytkownika do db_owner'');
    END
    ELSE
    BEGIN
        INSERT INTO #Results
        VALUES (DB_NAME(), N''DRY_RUN'',
                N''Uzytkownik zostanie dodany do db_owner'');
    END;
END;
';

    BEGIN TRY
        EXEC sys.sp_executesql
            @SQL,
            N'@LoginName sysname, @Execute bit',
            @LoginName = @LoginName,
            @Execute = @Execute;
    END TRY
    BEGIN CATCH
        INSERT INTO #Results
        VALUES
        (
            @DatabaseName,
            N'ERROR',
            ERROR_MESSAGE()
        );
    END CATCH;

    FETCH NEXT FROM db_cursor INTO @DatabaseName;
END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

------------------------------------------------------------
-- RAPORT
------------------------------------------------------------
SELECT
    DatabaseName,
    Status,
    Details
FROM #Results
ORDER BY DatabaseName;

DROP TABLE #Results;
GO
