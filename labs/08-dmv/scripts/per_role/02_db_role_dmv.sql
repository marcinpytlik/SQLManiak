/* =======================
   DMV access — Database
   (uruchom w docelowej bazie)
   ======================= */

USE [AdventureWorks2022];
GO

DECLARE @Login sysname = N'dmv_reader';  -- login z instancji, dla którego powstanie USER

/* 1) Role w bazie */
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_dmv_db')
    CREATE ROLE [role_dmv_db] AUTHORIZATION [dbo];

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_dmv_readers')
    CREATE ROLE [role_dmv_readers] AUTHORIZATION [dbo];

/* 2) Uprawnienia ról */
IF NOT EXISTS (
    SELECT 1
    FROM sys.database_permissions dp
    JOIN sys.database_principals  rp ON dp.grantee_principal_id = rp.principal_id
    WHERE rp.name = N'role_dmv_db' AND dp.permission_name = N'VIEW DATABASE STATE'
)
    GRANT VIEW DATABASE STATE TO [role_dmv_db];

IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dba')
    GRANT SELECT ON SCHEMA::[dba] TO [role_dmv_readers];

/* 3) USER w bazie powiązany z loginem */
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @Login)
BEGIN
    DECLARE @sqlCreateUser nvarchar(max) =
        N'CREATE USER ' + QUOTENAME(@Login) + N' FOR LOGIN ' + QUOTENAME(@Login) + N';';
    EXEC sys.sp_executesql @sqlCreateUser;
END

/* 4) Członkostwa w rolach — buduj DDL w zmiennej i wykonuj */
DECLARE @sql nvarchar(max);

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON r.principal_id = drm.role_principal_id
    JOIN sys.database_principals u ON u.principal_id = drm.member_principal_id
    WHERE r.name = N'role_dmv_db' AND u.name = @Login
)
BEGIN
    SET @sql = N'ALTER ROLE ' + QUOTENAME(N'role_dmv_db') + N' ADD MEMBER ' + QUOTENAME(@Login) + N';';
    EXEC sys.sp_executesql @sql;
END

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON r.principal_id = drm.role_principal_id
    JOIN sys.database_principals u ON u.principal_id = drm.member_principal_id
    WHERE r.name = N'role_dmv_readers' AND u.name = @Login
)
BEGIN
    SET @sql = N'ALTER ROLE ' + QUOTENAME(N'role_dmv_readers') + N' ADD MEMBER ' + QUOTENAME(@Login) + N';';
    EXEC sys.sp_executesql @sql;
END

/* 5) Weryfikacja (baza) */
PRINT N'--- DB: ' + DB_NAME() + N' ---';
SELECT dp.name AS db_user, dr.name AS db_role
FROM sys.database_role_members drm
JOIN sys.database_principals dr ON dr.principal_id = drm.role_principal_id
JOIN sys.database_principals dp ON dp.principal_id = drm.member_principal_id
WHERE dr.name IN (N'role_dmv_db', N'role_dmv_readers') AND dp.name = @Login;
