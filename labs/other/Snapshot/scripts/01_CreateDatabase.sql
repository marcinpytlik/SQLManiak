
-- 01_CreateDatabase.sql
-- Tworzy bazę testową i wypełnia danymi.
-- Uruchamiaj przez sqlcmd albo w SSMS/VS Code (T-SQL).

:setvar DatabaseName SnapshotDemoDB
:setvar DataPath C:\SQL\SnapshotDemo

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = '##MS_PolicyTsqlExecutionLogin##')
BEGIN
    -- noop, tylko przykład jak unikać nieistotnych warningów
END

PRINT '>> Tworzenie katalogu na dane (jeśli uruchomione przez sqlcmd/PowerShell zrobi to skrypt)';
-- Katalog twórz w PowerShell. Tu definiujemy tylko ścieżki plików.

DECLARE @db sysname = '$(DatabaseName)';
DECLARE @data nvarchar(260) = '$(DataPath)\' + @db + '_data.mdf';
DECLARE @log  nvarchar(260) = '$(DataPath)\' + @db + '_log.ldf';

IF DB_ID(@db) IS NOT NULL
BEGIN
    ALTER DATABASE [$(DatabaseName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$(DatabaseName)];
END
GO

DECLARE @db sysname = '$(DatabaseName)';
DECLARE @data nvarchar(260) = '$(DataPath)\' + @db + '_data.mdf';
DECLARE @log  nvarchar(260) = '$(DataPath)\' + @db + '_log.ldf';

EXEC('CREATE DATABASE ['+@db+']
ON ( NAME = '''+@db+'_data'', FILENAME = '''+@data+''', SIZE=1024MB, FILEGROWTH=256MB )
LOG ON ( NAME = '''+@db+'_log'', FILENAME = '''+@log+''', SIZE=512MB, FILEGROWTH=256MB );');
GO

ALTER DATABASE [$(DatabaseName)] SET RECOVERY SIMPLE;
ALTER DATABASE [$(DatabaseName)] SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE [$(DatabaseName)] SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO

USE [$(DatabaseName)];
GO

PRINT '>> Tworzenie tabeli i wypełnianie danymi...';
IF OBJECT_ID('dbo.Sales', 'U') IS NOT NULL DROP TABLE dbo.Sales;
CREATE TABLE dbo.Sales
(
    Id            int IDENTITY(1,1) PRIMARY KEY,
    CustomerId    int NOT NULL,
    OrderDate     datetime2 NOT NULL,
    Amount        money NOT NULL,
    Payload       char(200) NULL -- „balast” dla rozmiaru stron
);

;WITH gen AS
(
  SELECT TOP (1000000) -- ~1 mln wierszy
         ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
  FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Sales(CustomerId, OrderDate, Amount, Payload)
SELECT (n % 100000) + 1,
       DATEADD(day, -(n % 365), SYSUTCDATETIME()),
       (n % 10000) * 0.01,
       REPLICATE('X', 200)
FROM gen;

CHECKPOINT;
PRINT '>> Gotowe.';
