USE [master];
GO

/* Parametry */
DECLARE @Login     sysname       = N'new_reader';          -- NAZWA loginu
DECLARE @Password  nvarchar(256) = N'SilneHaslo!2025';     -- HASŁO (zmień)
DECLARE @DefaultDb sysname       = N'AdventureWorks2022';  -- preferowana default DB

/* Fallback dla default DB, jeśli nie istnieje */
DECLARE @DefaultDbForLogin sysname =
  CASE WHEN DB_ID(@DefaultDb) IS NOT NULL THEN @DefaultDb ELSE N'master' END;

/* 1) Utwórz login (jeśli nie istnieje) — hasło jako literał w dynamicznym DDL */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @Login)
BEGIN
  DECLARE @ddl nvarchar(max) =
      N'CREATE LOGIN ' + QUOTENAME(@Login) + N'
         WITH PASSWORD = ' + QUOTENAME(@Password, '''') + N',
              CHECK_POLICY = ON,
              CHECK_EXPIRATION = ON,
              DEFAULT_DATABASE = ' + QUOTENAME(@DefaultDbForLogin) + N';';

  EXEC(@ddl);
END
ELSE
  PRINT N'Login już istnieje — pomijam CREATE LOGIN.';

/* 2) (opcjonalnie) dodaj do roli serwerowej, jeśli używasz wariantu z VIEW SERVER STATE rolą */
/*
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
*/

/* 3) Weryfikacja */
SELECT name, is_disabled, default_database_name
FROM sys.sql_logins
WHERE name = @Login;
GO
/* 20_create_db_user_and_roles.sql — uruchom w DOCELowej bazie */
USE [AdventureWorks2022];
GO

DECLARE @Login sysname = N'new_reader';  -- <- login z instancji

/* Role (jeśli brak) */
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_dmv_cert_readers')
  CREATE ROLE [role_dmv_cert_readers] AUTHORIZATION [dbo];

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_dmv_readers')
  CREATE ROLE [role_dmv_readers] AUTHORIZATION [dbo];

/* Schemat dba (jeśli chcesz SELECT-y na widokach) */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dba')
  EXEC('CREATE SCHEMA dba AUTHORIZATION dbo;');

/* USER z loginu (dynamiczny DDL) */
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @Login)
BEGIN
  DECLARE @sql nvarchar(max) =
    N'CREATE USER ' + QUOTENAME(@Login) + N' FOR LOGIN ' + QUOTENAME(@Login) + N';';
  EXEC sys.sp_executesql @sql;
END

/* Uprawnienia roli czytającej widoki dba.* */
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dba')
  GRANT SELECT ON SCHEMA::[dba] TO [role_dmv_readers];

/* Członkostwo w rolach — zawsze przez @sql + sp_executesql */
IF NOT EXISTS (
  SELECT 1
  FROM sys.database_role_members drm
  JOIN sys.database_principals r ON r.principal_id = drm.role_principal_id
  JOIN sys.database_principals u ON u.principal_id = drm.member_principal_id
  WHERE r.name = N'role_dmv_cert_readers' AND u.name = @Login
)
BEGIN
  DECLARE @sql_add1 nvarchar(max) =
    N'ALTER ROLE ' + QUOTENAME(N'role_dmv_cert_readers') + N' ADD MEMBER ' + QUOTENAME(@Login) + N';';
  EXEC sys.sp_executesql @sql_add1;
END

IF NOT EXISTS (
  SELECT 1
  FROM sys.database_role_members drm
  JOIN sys.database_principals r ON r.principal_id = drm.role_principal_id
  JOIN sys.database_principals u ON u.principal_id = drm.member_principal_id
  WHERE r.name = N'role_dmv_readers' AND u.name = @Login
)
BEGIN
  DECLARE @sql_add2 nvarchar(max) =
    N'ALTER ROLE ' + QUOTENAME(N'role_dmv_readers') + N' ADD MEMBER ' + QUOTENAME(@Login) + N';';
  EXEC sys.sp_executesql @sql_add2;
END

/* Weryfikacja */
PRINT N'--- ' + DB_NAME() + N' ---';
SELECT dp.name AS db_user, dr.name AS db_role
FROM sys.database_role_members drm
JOIN sys.database_principals dr ON dr.principal_id = drm.role_principal_id
JOIN sys.database_principals dp ON dp.principal_id = drm.member_principal_id
WHERE dp.name = 'new_reader'
--@Login;

