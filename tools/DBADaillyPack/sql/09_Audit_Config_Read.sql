SET NOCOUNT ON;

DECLARE @mask nvarchar(260) = N'C:\SQLAudit\Audit_ServerConfigChanges*.sqlaudit'; -- CHANGE ME

BEGIN TRY
  SELECT TOP (200)
      event_time, succeeded, server_principal_name, session_server_principal_name,
      host_name, application_name, statement, action_id, class_type
  FROM sys.fn_get_audit_file(@mask, DEFAULT, DEFAULT)
  WHERE statement LIKE N'%sp_configure%' OR statement LIKE N'%RECONFIGURE%'
  ORDER BY event_time DESC;
END TRY
BEGIN CATCH
  SELECT
    GETDATE() AS event_time,
    CAST(0 AS bit) AS succeeded,
    SUSER_SNAME() AS server_principal_name,
    ORIGINAL_LOGIN() AS session_server_principal_name,
    HOST_NAME() AS host_name,
    APP_NAME() AS application_name,
    CONCAT(N'ERROR reading audit file. Mask=', @mask, N' ; ', ERROR_MESSAGE()) AS statement,
    NULL AS action_id,
    NULL AS class_type;
END CATCH;