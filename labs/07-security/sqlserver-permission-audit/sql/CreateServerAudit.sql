:setvar AuditName "Audit_PermChanges"
:setvar AuditPath "D:\SQLAudit\"

/* Tworzy audyt plikowy i włącza go.
   Uruchamiaj w trybie SQLCMD (SSMS: Query → SQLCMD Mode; sqlcmd: -v).
*/

IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = '$(AuditName)')
BEGIN
    PRINT 'Creating SERVER AUDIT [$(AuditName)] at $(AuditPath)';
    EXEC('CREATE SERVER AUDIT [' + REPLACE('$(AuditName)','''','''''') + ']
          TO FILE (FILEPATH = ''' + REPLACE('$(AuditPath)','''','''''') + ''',
                   MAXSIZE = 1 GB,
                   MAX_ROLLOVER_FILES = 10,
                   RESERVE_DISK_SPACE = OFF)
          WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);');
END
ELSE
BEGIN
    PRINT 'SERVER AUDIT [$(AuditName)] already exists.';
END
GO

ALTER SERVER AUDIT [$(AuditName)] WITH (STATE = ON);
GO
PRINT 'SERVER AUDIT [$(AuditName)] is ON.';
