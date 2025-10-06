:setvar AuditName "Audit_PermChanges"
:setvar ServerSpecName "SAS_PermChanges"

/* Opcjonalna specyfikacja: serwerowe loginy/role/uprawnienia */
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = '$(ServerSpecName)')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION [$(ServerSpecName)] WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION [$(ServerSpecName)];
END
GO

CREATE SERVER AUDIT SPECIFICATION [$(ServerSpecName)]
FOR SERVER AUDIT [$(AuditName)]
    ADD (SERVER_PERMISSION_CHANGE_GROUP),
    ADD (SERVER_OBJECT_PERMISSION_CHANGE_GROUP),
    ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP),
    ADD (SERVER_PRINCIPAL_CHANGE_GROUP)
WITH (STATE = ON);
GO

PRINT 'SERVER AUDIT SPEC [$(ServerSpecName)] created and ON.';
