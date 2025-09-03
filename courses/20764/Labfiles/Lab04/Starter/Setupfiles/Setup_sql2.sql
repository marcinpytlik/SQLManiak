USE master
GO

-- Drop and restore Databases
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'salesapp1')
BEGIN
	DROP DATABASE salesapp1;
END
GO


USE master
GO
IF EXISTS (SELECT * FROM sys.certificates WHERE name = 'TDE_cert')
	DROP CERTIFICATE TDE_cert;
GO
IF EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
	DROP MASTER KEY;
GO

