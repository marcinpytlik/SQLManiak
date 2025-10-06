:setvar AuditName "Audit_PermChanges"
:setvar DbName "YourDB"
:setvar DbSpecName "DAS_PermChanges"

/* Specyfikacja audytu w konkretnej bazie: GRANT/DENY/REVOKE, role i principal-e */
IF DB_ID('$(DbName)') IS NULL
BEGIN
    RAISERROR('Database $(DbName) does not exist.', 16, 1);
    RETURN;
END
GO

DECLARE @sql nvarchar(max) = N'
USE [' + REPLACE('$(DbName)',']',']]') + N'];

IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = ''' + REPLACE('$(DbSpecName)','''','''''') + N''')
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION [' + REPLACE('$(DbSpecName)',']',']]') + N'] WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION [' + REPLACE('$(DbSpecName)',']',']]') + N'];
END;

CREATE DATABASE AUDIT SPECIFICATION [' + REPLACE('$(DbSpecName)',']',']]') + N']
FOR SERVER AUDIT [' + REPLACE('$(AuditName)',']',']]') + N']
    ADD (DATABASE_PERMISSION_CHANGE_GROUP),
    ADD (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP),
    ADD (SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP),
    ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP),
    ADD (DATABASE_PRINCIPAL_CHANGE_GROUP)
WITH (STATE = ON);
';
EXEC (@sql);
PRINT 'DB AUDIT SPEC [' + '$(DbSpecName)' + '] created and ON in DB [' + '$(DbName)' + '].';
