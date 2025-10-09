-- Create log table for restore performance metrics in msdb
USE [msdb];
GO
IF OBJECT_ID('dbo.RestorePerfLog') IS NULL
BEGIN
    CREATE TABLE dbo.RestorePerfLog (
        id INT IDENTITY(1,1) PRIMARY KEY,
        test_date     DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),
        database_name SYSNAME      NOT NULL,
        restore_type  NVARCHAR(50) NOT NULL,
        duration_min  DECIMAL(10,2) NULL,
        read_mb       DECIMAL(18,2) NULL,
        write_mb      DECIMAL(18,2) NULL,
        cpu_sec       DECIMAL(18,2) NULL,
        source_db     SYSNAME NULL,
        notes         NVARCHAR(4000) NULL
    );
END
GO

-- Optional helper view: ostatnie testy na bazę
IF OBJECT_ID('dbo.v_RestorePerfSummary') IS NOT NULL
    DROP VIEW dbo.v_RestorePerfSummary;
GO
CREATE VIEW dbo.v_RestorePerfSummary AS
SELECT 
    database_name,
    COUNT(*) AS tests_count,
    AVG(duration_min) AS avg_duration_min,
    MIN(duration_min) AS min_duration_min,
    MAX(duration_min) AS max_duration_min,
    AVG(read_mb) AS avg_read_mb,
    AVG(write_mb) AS avg_write_mb,
    MAX(test_date) AS last_test_date
FROM dbo.RestorePerfLog
GROUP BY database_name;
GO

-- Helper proc to insert a row (for use from PowerShell)
IF OBJECT_ID('dbo.usp_RestorePerfLog_Upsert') IS NOT NULL
    DROP PROCEDURE dbo.usp_RestorePerfLog_Upsert;
GO
CREATE PROCEDURE dbo.usp_RestorePerfLog_Upsert
    @database_name SYSNAME,
    @restore_type  NVARCHAR(50),
    @duration_min  DECIMAL(10,2) = NULL,
    @read_mb       DECIMAL(18,2) = NULL,
    @write_mb      DECIMAL(18,2) = NULL,
    @cpu_sec       DECIMAL(18,2) = NULL,
    @source_db     SYSNAME = NULL,
    @notes         NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.RestorePerfLog (database_name, restore_type, duration_min, read_mb, write_mb, cpu_sec, source_db, notes)
    VALUES (@database_name, @restore_type, @duration_min, @read_mb, @write_mb, @cpu_sec, @source_db, @notes);
END
GO
