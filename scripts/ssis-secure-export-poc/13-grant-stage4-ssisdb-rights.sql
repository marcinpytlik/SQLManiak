/*
    POC: Secure SSIS Export without unconstrained delegation
    Stage 4 - minimum SSISDB permissions for proxy identity

    Expected deployment:
      Folder : POC_SSIS_Export
      Project: POC_SSIS_Export
      Login  : SQLLAB\poc-ssis-export
*/

SET NOCOUNT ON;
GO

USE [master];
GO

DECLARE @LoginName sysname = N'SQLLAB\poc-ssis-export';

IF SUSER_ID(@LoginName) IS NULL
BEGIN
    EXEC(N'CREATE LOGIN ' + QUOTENAME(@LoginName) + N' FROM WINDOWS;');
END;
GO

USE [SSISDB];
GO

DECLARE @LoginName sysname = N'SQLLAB\poc-ssis-export';
DECLARE @FolderName sysname = N'POC_SSIS_Export';
DECLARE @ProjectName sysname = N'POC_SSIS_Export';
DECLARE @ProjectId bigint;
DECLARE @PrincipalId int;

IF DATABASE_PRINCIPAL_ID(@LoginName) IS NULL
BEGIN
    EXEC(N'CREATE USER ' + QUOTENAME(@LoginName) + N' FOR LOGIN ' + QUOTENAME(@LoginName) + N';');
END;

SELECT @ProjectId = p.project_id
FROM catalog.projects AS p
JOIN catalog.folders AS f
    ON f.folder_id = p.folder_id
WHERE f.name = @FolderName
  AND p.name = @ProjectName;

IF @ProjectId IS NULL
BEGIN
    THROW 53001, 'Stage 4 SSIS project was not found in SSISDB. Deploy the project first.', 1;
END;

SELECT @PrincipalId = principal_id
FROM sys.database_principals
WHERE name = @LoginName;

IF @PrincipalId IS NULL
BEGIN
    THROW 53002, 'SSISDB database principal for the export account was not found.', 1;
END;

-- READ on this project only.
EXEC catalog.grant_permission
     @object_type = 2,
     @object_id = @ProjectId,
     @principal_id = @PrincipalId,
     @permission_type = 1;

-- EXECUTE on this project only.
EXEC catalog.grant_permission
     @object_type = 2,
     @object_id = @ProjectId,
     @principal_id = @PrincipalId,
     @permission_type = 3;

SELECT
    f.name AS FolderName,
    p.name AS ProjectName,
    dp.name AS PrincipalName,
    ep.permission_type,
    CASE ep.permission_type
        WHEN 1 THEN N'READ'
        WHEN 3 THEN N'EXECUTE'
        ELSE CONVERT(nvarchar(20), ep.permission_type)
    END AS PermissionName
FROM catalog.explicit_object_permissions AS ep
JOIN catalog.projects AS p
    ON ep.object_type = 2
   AND ep.object_id = p.project_id
JOIN catalog.folders AS f
    ON f.folder_id = p.folder_id
JOIN sys.database_principals AS dp
    ON dp.principal_id = ep.principal_id
WHERE f.name = @FolderName
  AND p.name = @ProjectName
  AND dp.name = @LoginName
ORDER BY ep.permission_type;
GO