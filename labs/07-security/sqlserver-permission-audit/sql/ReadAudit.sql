:setvar AuditPath "D:\SQLAudit\Audit_PermChanges_*.sqlaudit"

/* Szybki podgląd plików audytu */
SELECT TOP (2000)
    event_time,
    session_server_principal_name   AS wykonawca_login,
    server_principal_name,
    database_principal_name,
    host_name,
    application_name,
    database_name,
    schema_name,
    object_name,
    statement,
    event_name,
    action_id,
    succeeded
FROM sys.fn_get_audit_file('$(AuditPath)', DEFAULT, DEFAULT)
WHERE event_name LIKE '%PERMISSION_CHANGE%'
   OR event_name LIKE '%ROLE_MEMBER_CHANGE%'
ORDER BY event_time DESC;
