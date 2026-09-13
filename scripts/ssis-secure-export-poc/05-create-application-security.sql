/*
    POC: Secure SSIS Export without unconstrained delegation
    Stage 2 - Application login security

    Domain: SQLLAB.LOCAL
    Application account: SQLLAB\poc-ssis-app
*/

USE [master];
GO

DECLARE @AppLogin sysname = N'SQLLAB\poc-ssis-app';
DECLARE @sql nvarchar(max);

IF SUSER_ID(@AppLogin) IS NULL
BEGIN
    SET @sql = N'CREATE LOGIN ' + QUOTENAME(@AppLogin) + N' FROM WINDOWS;';
    EXEC sys.sp_executesql @sql;
END;
GO

USE [SSIS_Delegation_Lab];
GO

DECLARE @AppLogin sysname = N'SQLLAB\poc-ssis-app';
DECLARE @sql nvarchar(max);

IF USER_ID(@AppLogin) IS NULL
BEGIN
    SET @sql = N'CREATE USER ' + QUOTENAME(@AppLogin) + N' FOR LOGIN ' + QUOTENAME(@AppLogin) + N';';
    EXEC sys.sp_executesql @sql;
END;

-- Minimal application permission: execute only the request procedure.
SET @sql = N'GRANT EXECUTE ON OBJECT::dbo.usp_RequestExport TO ' + QUOTENAME(@AppLogin) + N';';
EXEC sys.sp_executesql @sql;

-- Explicitly prevent direct access to the queue table.
SET @sql = N'DENY SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.ExportRequest TO ' + QUOTENAME(@AppLogin) + N';';
EXEC sys.sp_executesql @sql;

-- The account intentionally receives no permissions in msdb or SSISDB.
-- It also receives no SQL Agent role membership and no access to credentials/proxies.
GO

SELECT
    dp.name AS DatabasePrincipal,
    dp.type_desc,
    p.permission_name,
    p.state_desc,
    OBJECT_SCHEMA_NAME(p.major_id) AS ObjectSchema,
    OBJECT_NAME(p.major_id) AS ObjectName
FROM sys.database_principals AS dp
LEFT JOIN sys.database_permissions AS p
    ON p.grantee_principal_id = dp.principal_id
WHERE dp.name = N'SQLLAB\poc-ssis-app'
ORDER BY ObjectName, p.permission_name;
GO
