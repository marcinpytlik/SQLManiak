DECLARE @execution_id BIGINT;

EXEC SSISDB.catalog.create_execution
    @package_name = N'Package.dtsx',
    @execution_id = @execution_id OUTPUT,
    @folder_name = N'App',
    @project_name = N'ETL',
    @use32bitruntime = False;

EXEC SSISDB.catalog.set_execution_parameter_value
    @execution_id = @execution_id,
    @object_type = 50,
    @parameter_name = N'User::Folder',
    @parameter_value = N'\\FS\Share\Inbox';

EXEC SSISDB.catalog.start_execution @execution_id;