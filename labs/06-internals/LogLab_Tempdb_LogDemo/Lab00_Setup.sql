/* Lab 00 — Setup (czysta piaskownica) */
USE master;
IF DB_ID('LogLab') IS NOT NULL
BEGIN
    ALTER DATABASE LogLab SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LogLab;
END
GO
CREATE DATABASE LogLab;
GO

/* Pełny recovery + pełna kopia – bez tego BACKUP LOG w FULL nie skróci przestrzeni */
ALTER DATABASE LogLab SET RECOVERY FULL;
GO
BACKUP DATABASE LogLab TO DISK = 'C:\Temp\LogLab_full.bak' WITH INIT, COMPRESSION;
GO

USE LogLab;
IF OBJECT_ID('dbo.BigT','U') IS NOT NULL DROP TABLE dbo.BigT;
CREATE TABLE dbo.BigT(
    Id  INT IDENTITY(1,1) CONSTRAINT PK_BigT PRIMARY KEY,
    Pad CHAR(8000) NOT NULL DEFAULT REPLICATE('X',8000)
);
GO

/* Zegarki diagnostyczne */
SELECT * FROM sys.dm_db_log_stats(DB_ID());  -- total_log_size_mb, active_log_size_mb, log_truncation_holdup_reason
DBCC SQLPERF(LOGSPACE);
SELECT * FROM sys.dm_db_log_info(DB_ID());
