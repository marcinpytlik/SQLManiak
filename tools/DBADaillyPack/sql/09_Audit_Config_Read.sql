/* Read Server Audit files for server config changes (sp_configure/reconfigure).
   Update file mask to your audit path/name.
*/
SET NOCOUNT ON;

DECLARE @mask nvarchar(260) = N'C:\SQLAudit\Audit_ServerConfigChanges*.sqlaudit'; -- <-- CHANGE ME

SELECT TOP (200)
    event_time,
    succeeded,
    server_principal_name,
    session_server_principal_name,
    host_name,
    application_name,
    statement,
    action_id,
    class_type
FROM sys.fn_get_audit_file(@mask, DEFAULT, DEFAULT)
WHERE statement LIKE N'%sp_configure%'
   OR statement LIKE N'%RECONFIGURE%'
ORDER BY event_time DESC;
