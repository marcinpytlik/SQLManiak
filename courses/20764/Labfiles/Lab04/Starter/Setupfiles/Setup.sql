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



IF EXISTS (SELECT * FROM sys.server_audits WHERE name = 'activity_audit')
BEGIN
	IF EXISTS (SELECT * FROM sys.server_audits WHERE name = 'activity_audit' AND is_state_enabled = 1)
	BEGIN
		ALTER SERVER AUDIT activity_audit WITH (STATE = OFF);
	END
	DROP SERVER AUDIT activity_audit;
END
GO

IF EXISTS (SELECT * FROM sys.server_audit_specifications WHERE name = 'audit_logins')
BEGIN
	IF EXISTS (SELECT * FROM sys.server_audit_specifications WHERE name = 'audit_logins' AND is_state_enabled = 1)
		ALTER SERVER AUDIT SPECIFICATION audit_logins WITH (STATE = OFF);

	DROP SERVER AUDIT SPECIFICATION audit_logins
END
GO

USE master;
GO
IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'marketing_app')
	DROP LOGIN marketing_app

CREATE LOGIN marketing_app WITH PASSWORD = '5ql53rv3r!'

USE salesapp1;
GO
CREATE USER marketing_user FOR LOGIN marketing_app
GO

GRANT SELECT ON HR.Employees TO marketing_user;
GRANT UPDATE ON HR.Employees TO marketing_user;

GO

USE master
GO
IF EXISTS (SELECT * FROM sys.certificates WHERE name = 'TDE_cert')
	DROP CERTIFICATE TDE_cert;
GO
IF EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
	DROP MASTER KEY;
GO

