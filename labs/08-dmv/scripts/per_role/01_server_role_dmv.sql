USE [master];
GO

/* Parametry */
DECLARE @Login     sysname       = N'dmv_reader';      -- nazwa loginu SQL
DECLARE @Password  nvarchar(256) = N'P@ssw0rd';        -- ZMIEŃ!
DECLARE @Db        sysname       = N'AdventureWorks2022';  -- preferowana domyślna baza

/* 1) Rola serwerowa + uprawnienia DMV (instancja) */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'role_dmv_server')
    CREATE SERVER ROLE [role_dmv_server] AUTHORIZATION [sa];

IF NOT EXISTS (
    SELECT 1
    FROM sys.server_permissions sp
    JOIN sys.server_principals  rp ON sp.grantee_principal_id = rp.principal_id
    WHERE rp.name = N'role_dmv_server' AND sp.permission_name = N'VIEW SERVER STATE'
)
    GRANT VIEW SERVER STATE TO [role_dmv_server];
-- (opcjonalnie) GRANT VIEW ANY DEFINITION TO [role_dmv_server];

/* 2) Login SQL (fallback na master jeśli @Db nie istnieje) */
DECLARE @DefaultDbForLogin sysname =
    CASE WHEN DB_ID(@Db) IS NOT NULL THEN @Db ELSE N'master' END;

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @Login)
BEGIN
    DECLARE @sqlCreateLogin nvarchar(max) =
        N'CREATE LOGIN ' + QUOTENAME(@Login) + N'
          WITH PASSWORD = @pwd,
               CHECK_POLICY = ON,
               CHECK_EXPIRATION = ON,
               DEFAULT_DATABASE = ' + QUOTENAME(@DefaultDbForLogin) + N';';

    EXEC sys.sp_executesql
         @sqlCreateLogin,
         N'@pwd nvarchar(256)',
         @pwd = @Password;
END
ELSE
    PRINT N'Login istnieje — pomijam CREATE LOGIN.';

/* 3) Dodaj login do roli serwerowej */
IF NOT EXISTS (
    SELECT 1
    FROM sys.server_role_members m
    JOIN sys.server_principals r ON r.principal_id = m.role_principal_id
    JOIN sys.server_principals p ON p.principal_id = m.member_principal_id
    WHERE r.name = N'role_dmv_server' AND p.name = @Login
)
BEGIN
    DECLARE @sqlAdd nvarchar(max) =
        N'ALTER SERVER ROLE ' + QUOTENAME(N'role_dmv_server') + N' ADD MEMBER ' + QUOTENAME(@Login) + N';';
    EXEC(@sqlAdd);
END

/* 4) Weryfikacja (instancja) */
PRINT N'--- SERVER ---';
SELECT p.name AS login_name, r.name AS server_role
FROM sys.server_role_members m
JOIN sys.server_principals r ON m.role_principal_id = r.principal_id
JOIN sys.server_principals p ON m.member_principal_id = p.principal_id
WHERE r.name = N'role_dmv_server' AND p.name = @Login;

SELECT SERVERPROPERTY('IsIntegratedSecurityOnly') AS WindowsOnly;
EXEC xp_readerrorlog 0, 1, N'Login failed for user', N'dmv_reader';
ALTER LOGIN dmv_reader WITH PASSWORD = N'Nowe_BardzoSilneHaslo!2025', CHECK_POLICY = ON, CHECK_EXPIRATION = ON;