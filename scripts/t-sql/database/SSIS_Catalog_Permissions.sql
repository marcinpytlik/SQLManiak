USE SSISDB;
GO
EXEC sp_addrolemember N'db_datareader', N'DOMAIN\user';
DECLARE @principal_id INT = DATABASE_PRINCIPAL_ID(N'DOMAIN\user');
EXEC catalog.grant_permission @object_type = 1, @object_id = (SELECT folder_id FROM catalog.folders WHERE name = N'App'),
    @principal_id = @principal_id, @permission_type = 1;
EXEC catalog.grant_permission @object_type = 1, @object_id = (SELECT folder_id FROM catalog.folders WHERE name = N'App'),
    @principal_id = @principal_id, @permission_type = 2;
EXEC catalog.grant_permission @object_type = 1, @object_id = (SELECT folder_id FROM catalog.folders WHERE name = N'App'),
    @principal_id = @principal_id, @permission_type = 3;