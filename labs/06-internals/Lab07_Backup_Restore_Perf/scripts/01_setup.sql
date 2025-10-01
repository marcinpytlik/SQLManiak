-- scripts/01_setup.sql
USE master;
IF DB_ID('BkpLab') IS NOT NULL BEGIN ALTER DATABASE BkpLab SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE BkpLab; END;
GO

CREATE DATABASE BkpLab
ON PRIMARY (NAME=N'BkpLab', FILENAME='C:\SQLData\BkpLab.mdf', SIZE=2048MB, FILEGROWTH=256MB)
LOG ON (NAME=N'BkpLab_log', FILENAME='C:\SQLData\BkpLab_log.ldf', SIZE=512MB, FILEGROWTH=256MB);
GO
ALTER DATABASE BkpLab SET RECOVERY FULL;
GO

USE BkpLab;
GO
-- Duża tabela (~1GB+ w zależności od środowiska)
CREATE TABLE dbo.BigData (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Filler CHAR(4000) NOT NULL DEFAULT REPLICATE('D',4000)
);
;WITH n AS (
    SELECT TOP (400000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT dbo.BigData DEFAULT VALUES;
GO

-- Checkpoint + backup log startowy, żeby łańcuch logów był spójny
CHECKPOINT;
BACKUP LOG BkpLab TO DISK = 'C:\SQLBackups\BkpLab_init.trn' WITH INIT;
