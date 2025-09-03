USE master
GO

-- Drop and restore Databases
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'salesapp1')
BEGIN
	DROP DATABASE salesapp1
END
GO



RESTORE DATABASE salesapp1 FROM  DISK = N'D:\SetupFiles\salesapp1.bak' WITH  REPLACE,
MOVE N'TSQL' TO N'$(SUBDIR)SetupFiles\salesapp1.mdf', 
MOVE N'TSQL_Log' TO N'$(SUBDIR)SetupFiles\salesapp1.ldf'
GO
ALTER AUTHORIZATION ON DATABASE::salesapp1 TO [ADVENTUREWORKS\Student];
GO

IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'AdventureWorks')
BEGIN
	DROP DATABASE AdventureWorks
END
GO



IF EXISTS (SELECT * FROM sys.server_audits WHERE name = 'MIASQL_Audit')
BEGIN
	IF EXISTS (SELECT * FROM sys.server_audits WHERE name = 'MIASQL_Audit' AND is_state_enabled = 1)
	BEGIN
		ALTER SERVER AUDIT MIASQL_Audit WITH (STATE = OFF);
	END
	DROP SERVER AUDIT MIASQL_Audit;
END
GO

IF EXISTS (SELECT * FROM sys.server_audit_specifications WHERE name = 'AuditLogins')
BEGIN
	IF EXISTS (SELECT * FROM sys.server_audit_specifications WHERE name = 'AuditLogins' AND is_state_enabled = 1)
		ALTER SERVER AUDIT SPECIFICATION AuditLogins WITH (STATE = OFF);

	DROP SERVER AUDIT SPECIFICATION AuditLogins
END
GO

USE salesapp1;
GO
CREATE USER [test_user] WITHOUT LOGIN
GO




