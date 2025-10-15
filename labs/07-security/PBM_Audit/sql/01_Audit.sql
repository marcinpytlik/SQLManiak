/* 01_Audit.sql
   Server Audit + Server Audit Specification (SQL Server 2022)
   Uwaga: dostosuj FILEPATH na środowisku docelowym.
*/

/*** Konfiguracja ***/
DECLARE @AuditPath nvarchar(260) = N'E:\SQLAudit\'; -- FCI: współdzielony dysk
DECLARE @AuditName sysname = N'Audit_Config_Changes';
DECLARE @SpecName  sysname = N'Audit_Config_Changes_Spec';

/*** 1. Server Audit ***/
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = @AuditName)
BEGIN
    EXEC (N'CREATE SERVER AUDIT [' + @AuditName + N']
          TO FILE (FILEPATH = N''' + @AuditPath + N''', MAXSIZE = 1 GB, MAX_ROLLOVER_FILES = 32)
          WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);');
END

IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = @AuditName AND is_state_enabled = 1)
BEGIN
    EXEC (N'ALTER SERVER AUDIT [' + @AuditName + N'] WITH (STATE = ON);');
END
GO

/*** 2. Server Audit Specification ***/
IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = @SpecName)
BEGIN
    EXEC (N'CREATE SERVER AUDIT SPECIFICATION [' + @SpecName + N']
           FOR SERVER AUDIT [' + @AuditName + N']
               ADD (DATABASE_CHANGE_GROUP),
               ADD (SERVER_OBJECT_CHANGE_GROUP),
               ADD (SERVER_OPERATION_GROUP)
           WITH (STATE = ON);');
END
ELSE
BEGIN
    EXEC (N'ALTER SERVER AUDIT SPECIFICATION [' + @SpecName + N'] WITH (STATE = ON);');
END
GO

PRINT 'Audit ON: sprawdź, czy pliki *.sqlaudit tworzą się w katalogu docelowym.';
