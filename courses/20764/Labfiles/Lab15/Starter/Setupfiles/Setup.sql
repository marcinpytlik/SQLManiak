USE master
GO

-- Drop and restore Databases
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'salesapp1')
BEGIN
	DROP DATABASE salesapp1
END
GO

IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'AdventureWorks')
BEGIN
	DROP DATABASE AdventureWorks
END
GO

RESTORE DATABASE [AdventureWorks] FROM  DISK = N'D:\SetupFiles\AdventureWorks2016.bak' WITH  REPLACE,
MOVE N'AdventureWorks2016CTP3_Data' TO N'$(SUBDIR)SetupFiles\AdventureWorks_Data.mdf', 
MOVE N'AdventureWorks2016CTP3_Log' TO N'$(SUBDIR)SetupFiles\AdventureWorks_log.ldf',
MOVE N'AdventureWorks2016CTP3_mod' TO N'$(SUBDIR)SetupFiles\AdventureWorks_mod'
GO
ALTER AUTHORIZATION ON DATABASE::AdventureWorks TO [ADVENTUREWORKS\Student];
GO

USE AdventureWorks;
GO

CREATE SCHEMA Accounts;
GO

CREATE TABLE Accounts.CurrencyCode
(currency_code char(3) PRIMARY KEY,
 currency_numeric_code smallint NOT NULL,
 minor_unit_decimal_places tinyint NULL,
 currency_name varchar(100) NOT NULL
)
GO 

CREATE TABLE Accounts.ExchangeRate
(from_currency_code char(3) NOT NULL,
 to_currency_code char(3) NOT NULL,
 rate_date date NOT NULL,
 rate decimal (18,4),
 CONSTRAINT PK_ExchangeRate PRIMARY KEY
 (from_currency_code, to_currency_code, rate_date),
 CONSTRAINT FK_ExchangeRate_CurrencyCode_from FOREIGN KEY (from_currency_code) 
  REFERENCES Accounts.CurrencyCode (currency_code),
 CONSTRAINT FK_ExchangeRate_CurrencyCode_to FOREIGN KEY (to_currency_code) 
  REFERENCES Accounts.CurrencyCode (currency_code)
)
GO
ALTER TABLE Accounts.ExchangeRate WITH CHECK CHECK CONSTRAINT FK_ExchangeRate_CurrencyCode_from;
ALTER TABLE Accounts.ExchangeRate WITH CHECK CHECK CONSTRAINT FK_ExchangeRate_CurrencyCode_to;
GO
CREATE INDEX ix_ExchangeRate_01 ON Accounts.ExchangeRate (rate_date, from_currency_code, to_currency_code) INCLUDE (rate);
CREATE INDEX ix_ExchangeRate_02 ON Accounts.ExchangeRate (rate_date, to_currency_code, from_currency_code) INCLUDE (rate);
GO

CREATE PROC Sales.usp_prospect_list
AS
	SET NOCOUNT ON
	SELECT TOP (ABS(CHECKSUM(NEWID())) % 250 + 250) 
	CustomerId, FirstName, LastName, EmailAddress, PhoneNumber
	FROM Sales.CustomerPII
	ORDER BY NEWID(), CustomerId
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'FixedAsset_user')
	DROP LOGIN FixedAsset_user

IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'FixedAssets_1.0.9.1')
BEGIN
	DROP DATABASE [FixedAssets_1.0.9.1]
END
IF EXISTS(SELECT * FROM sys.sysdatabases WHERE name = 'FixedAssets')
BEGIN
	DROP DATABASE FixedAssets
END

DECLARE @dac_id uniqueidentifier;
SELECT @dac_id = instance_id from msdb.dbo.sysdac_instances WHERE instance_name = 'FixedAssets_1.0.9.1';
IF @dac_id IS NOT NULL
	EXEC msdb.dbo.sp_sysdac_delete_instance @dac_id;

SELECT @dac_id = instance_id from msdb.dbo.sysdac_instances WHERE instance_name = 'FixedAssets';
IF @dac_id IS NOT NULL
	EXEC msdb.dbo.sp_sysdac_delete_instance @dac_id;