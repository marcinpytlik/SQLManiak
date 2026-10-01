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


USE salesapp1
GO

CREATE TABLE dbo.TopLevelDomain
(Domain varchar(100) NOT NULL PRIMARY KEY,
 FileVersion varchar(50) NOT NULL
)
GO

-- Create Finance
IF EXISTS(SELECT * FROM sys.databases WHERE name = 'Finance')
	DROP DATABASE Finance;
GO

CREATE DATABASE Finance ON  PRIMARY 
(  NAME = N'Finance', 
   FILENAME = N'$(SUBDIR)SetupFiles\Finance.mdf' , 
   SIZE = 10240KB, 
   FILEGROWTH = 1024KB 
)
 LOG ON 
( NAME = N'Finance_log', 
  FILENAME = N'$(SUBDIR)SetupFiles\Finance_log.ldf' , 
  SIZE = 5120KB, 
  FILEGROWTH = 10%
);
GO

EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = 'Finance';
GO

-- Set the full recovery model
ALTER DATABASE Finance SET RECOVERY SIMPLE;
GO

--  Create a table in the database
CREATE TABLE [Finance].[dbo].[Currency](
	[CurrencyCode] [nchar](3) NOT NULL PRIMARY KEY,
	[Name] [nvarchar](50) NOT NULL,
	[ModifiedDate] [datetime] NOT NULL CONSTRAINT [DF_Currency_ModifiedDate] DEFAULT (getdate()) 
	);
GO


CREATE TABLE [Finance].[dbo].[SalesTaxRate](
	[SalesTaxRateID] [int] NOT NULL PRIMARY KEY,
	[StateProvinceID] [int] NOT NULL,
	[TaxType] [tinyint] NOT NULL,
	[TaxRate] [smallmoney] NOT NULL CONSTRAINT [DF_SalesTaxRate_TaxRate]  DEFAULT ((0.00)),
	[Name] [nvarchar](50) NOT NULL,
	[rowguid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_SalesTaxRate_rowguid]  DEFAULT (newid()),
	[ModifiedDate] [datetime] NOT NULL CONSTRAINT [DF_SalesTaxRate_ModifiedDate]  DEFAULT (getdate()),
 );
GO



--remove the financeDAC DAC
DECLARE @dac_id uniqueidentifier;
SELECT @dac_id = instance_id from msdb.dbo.sysdac_instances WHERE instance_name = 'FinanceDAC';
IF @dac_id IS NOT NULL
	EXEC msdb.dbo.sp_sysdac_delete_instance @dac_id;

IF EXISTS(SELECT * FROM sys.databases WHERE name = 'FinanceDAC')
	DROP DATABASE FinanceDAC;
GO