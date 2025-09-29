
/*
    DBA_Install_Tempdb_Control.sql
    Creates:
      - DBA database (if missing)
      - Tables: TempdbHealthLog (and safe placeholders for FileGrowthLog, VersionStoreUsageLog, LongTransactionsLog)
      - Procedure: Alert_TempdbHealth
      - Views (DBA): vLongTransactions, vOldestTransaction_60m, vAutogrowLastHour, vAutogrowHourly_24h,
                     vVersionStore15min, vVersionStoreLatest, vDbFileSizes, vWaitsTop,
                     vTempdbHealthLast, vTempdbHealthAlerts24h, vTempdbHealthHourly_24h
    Target: SQL Server 2019+
*/

/* 0) Ensure DBA database exists */
IF DB_ID('DBA') IS NULL
BEGIN
    PRINT 'Creating DBA database...';
    EXEC ('CREATE DATABASE DBA');
END
GO

USE DBA;
GO

/* 1) Tables */

/* 1.1 TempdbHealthLog (main) */
IF OBJECT_ID('dbo.TempdbHealthLog') IS NULL
BEGIN
    PRINT 'Creating dbo.TempdbHealthLog...';
    CREATE TABLE dbo.TempdbHealthLog
    (
        Id               BIGINT IDENTITY(1,1) PRIMARY KEY,
        LoggedAtUtc      DATETIME2 NOT NULL CONSTRAINT DF_TempdbHealth_LoggedAtUtc DEFAULT SYSUTCDATETIME(),
        VersionStoreGB   DECIMAL(18,2) NOT NULL,
        TempdbTotalGB    DECIMAL(18,2) NOT NULL,
        TempdbFreeGB     DECIMAL(18,2) NOT NULL,
        DiskFreeGB       DECIMAL(18,2) NOT NULL,
        DrivesCsv        NVARCHAR(200) NULL,
        ThresholdVS_GB   DECIMAL(18,2) NOT NULL,
        ThresholdDisk_GB DECIMAL(18,2) NOT NULL,
        IsVSExceeded     BIT NOT NULL,
        IsDiskExceeded   BIT NOT NULL,
        Note             NVARCHAR(4000) NULL
    );
    CREATE INDEX IX_TempdbHealth_LoggedAtUtc ON dbo.TempdbHealthLog(LoggedAtUtc);
END
GO

/* 1.2 Placeholder: FileGrowthLog (for views) */
IF OBJECT_ID('dbo.FileGrowthLog') IS NULL
BEGIN
    PRINT 'Creating placeholder dbo.FileGrowthLog (you can replace with collector job output)...';
    CREATE TABLE dbo.FileGrowthLog
    (
        Id           BIGINT IDENTITY(1,1) PRIMARY KEY,
        EventTime    DATETIME2 NOT NULL,
        DatabaseName SYSNAME   NULL,
        FileName     NVARCHAR(260) NULL,
        FileType     NVARCHAR(20)  NULL,
        SizeBeforeMB DECIMAL(18,2) NULL,
        SizeAfterMB  DECIMAL(18,2) NULL,
        GrowthMB     DECIMAL(18,2) NULL,
        IsAuto       BIT           NULL,
        EventName    NVARCHAR(128) NULL
    );
    CREATE INDEX IX_FileGrowthLog_EventTime ON dbo.FileGrowthLog(EventTime);
    CREATE INDEX IX_FileGrowthLog_DbTime    ON dbo.FileGrowthLog(DatabaseName, EventTime);
END
GO

/* 1.3 Placeholder: VersionStoreUsageLog (for views) */
IF OBJECT_ID('dbo.VersionStoreUsageLog') IS NULL
BEGIN
    PRINT 'Creating placeholder dbo.VersionStoreUsageLog (you can replace with collector job output)...';
    CREATE TABLE dbo.VersionStoreUsageLog
    (
        Id             BIGINT IDENTITY(1,1) PRIMARY KEY,
        CollectedAt    DATETIME2 NOT NULL CONSTRAINT DF_VS_CollectedAt DEFAULT SYSUTCDATETIME(),
        DatabaseId     INT       NOT NULL,
        DatabaseName   SYSNAME   NOT NULL,
        VersionStoreKB BIGINT    NOT NULL
    );
    CREATE INDEX IX_VS_Time ON dbo.VersionStoreUsageLog(CollectedAt);
    CREATE INDEX IX_VS_Db   ON dbo.VersionStoreUsageLog(DatabaseId, CollectedAt);
END
GO

/* 1.4 Placeholder: LongTransactionsLog (for views) */
IF OBJECT_ID('dbo.LongTransactionsLog') IS NULL
BEGIN
    PRINT 'Creating placeholder dbo.LongTransactionsLog (you can replace with LongTx job output)...';
    CREATE TABLE dbo.LongTransactionsLog
    (
        LogID           INT IDENTITY(1,1) PRIMARY KEY,
        SessionID       INT,
        TransactionID   BIGINT,
        DatabaseName    SYSNAME NULL,
        LoginName       SYSNAME NULL,
        HostName        SYSNAME NULL,
        ProgramName     NVARCHAR(256) NULL,
        BeginTime       DATETIME2 NOT NULL,
        MinutesOpen     INT NOT NULL,
        WaitType        NVARCHAR(120) NULL,
        BlockingSession INT NULL,
        StatementText   NVARCHAR(MAX) NULL,
        LoggedAt        DATETIME2 NOT NULL CONSTRAINT DF_LongTx_LoggedAt DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_LongTransactionsLog_LoggedAt ON dbo.LongTransactionsLog(LoggedAt);
    CREATE INDEX IX_LongTransactionsLog_MinutesOpen ON dbo.LongTransactionsLog(MinutesOpen);
END
GO

/* 2) Procedure: Alert_TempdbHealth */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROC dbo.Alert_TempdbHealth
    @VersionStoreGBThreshold DECIMAL(18,2) = 10.0,      -- threshold VS (GB)
    @DiskFreeGBThreshold     DECIMAL(18,2) = 20.0,      -- min free on volumes (GB)
    @MailProfile             SYSNAME = NULL,            -- Database Mail profile
    @MailRecipients          NVARCHAR(4000) = NULL      -- recipients ; - separated
AS
BEGIN
    SET NOCOUNT ON;

    /* Gather tempdb metrics */
    DECLARE @vs_gb DECIMAL(18,2)
          , @temp_total_gb DECIMAL(18,2)
          , @temp_free_gb  DECIMAL(18,2);

    SELECT
        @vs_gb = CAST(SUM(version_store_reserved_page_count)*8.0/1024.0/1024.0 AS DECIMAL(18,2))
    FROM tempdb.sys.dm_db_file_space_usage;

    SELECT
        @temp_total_gb = CAST(SUM(size)*8.0/1024.0/1024.0 AS DECIMAL(18,2))
    FROM tempdb.sys.database_files;

    SELECT
        @temp_free_gb = CAST(SUM(unallocated_extent_page_count)*8.0/1024.0/1024.0 AS DECIMAL(18,2))
    FROM tempdb.sys.dm_db_file_space_usage;

    /* Resolve volumes containing tempdb files */
    DECLARE @drives TABLE(Drive NVARCHAR(2) PRIMARY KEY);
    INSERT INTO @drives(Drive)
    SELECT DISTINCT UPPER(LEFT(physical_name,2))
    FROM tempdb.sys.database_files
    WHERE physical_name LIKE '[A-Z]%' AND LEFT(physical_name,2) LIKE '[A-Z]:';

    DECLARE @disk TABLE(Drive NVARCHAR(2) PRIMARY KEY, FreeMB BIGINT);
    BEGIN TRY
        INSERT INTO @disk(Drive, FreeMB)
        EXEC master..xp_fixeddrives;
    END TRY
    BEGIN CATCH
        -- ignore if not available
    END CATCH;

    DECLARE @drivesCsv NVARCHAR(200) =
      STUFF( (SELECT ';'+d.Drive FROM @drives d FOR XML PATH(''), TYPE).value('.','nvarchar(max)'), 1, 1, '');

    DECLARE @disk_free_gb DECIMAL(18,2) =
    (
        SELECT CAST(MIN(CAST(x.FreeMB AS DECIMAL(18,2))/1024.0) AS DECIMAL(18,2))
        FROM @drives dv
        JOIN @disk   x  ON x.Drive = dv.Drive
    );

    IF @disk_free_gb IS NULL SET @disk_free_gb = -1;

    /* Threshold checks */
    DECLARE @isVSExceeded   BIT = CASE WHEN @vs_gb        >= @VersionStoreGBThreshold THEN 1 ELSE 0 END;
    DECLARE @isDiskExceeded BIT = CASE WHEN @disk_free_gb >= 0 AND @disk_free_gb <= @DiskFreeGBThreshold THEN 1 ELSE 0 END;

    /* Log row */
    INSERT INTO dbo.TempdbHealthLog
    (
        VersionStoreGB, TempdbTotalGB, TempdbFreeGB, DiskFreeGB, DrivesCsv,
        ThresholdVS_GB, ThresholdDisk_GB, IsVSExceeded, IsDiskExceeded, Note
    )
    VALUES
    (
        @vs_gb, @temp_total_gb, @temp_free_gb, @disk_free_gb, @drivesCsv,
        @VersionStoreGBThreshold, @DiskFreeGBThreshold, @isVSExceeded, @isDiskExceeded,
        CASE WHEN @disk_free_gb < 0 THEN N'xp_fixeddrives did not return a matching volume for tempdb.' ELSE NULL END
    );

    /* Optional email */
    IF (@isVSExceeded = 1 OR @isDiskExceeded = 1)
       AND @MailProfile IS NOT NULL AND @MailRecipients IS NOT NULL
    BEGIN
        DECLARE @subject NVARCHAR(255) = N'[SQL][Tempdb] Alert: ' +
            CASE WHEN @isVSExceeded=1 THEN N'VersionStore ' ELSE N'' END +
            CASE WHEN @isDiskExceeded=1 THEN N'DiskFree '     ELSE N'' END;

        DECLARE @body NVARCHAR(MAX) =
            N'UTC: ' + CONVERT(nvarchar(30), SYSUTCDATETIME(), 126) + CHAR(13)+CHAR(10) +
            N'VS (GB): ' + CONVERT(nvarchar(30), @vs_gb) + N' (thr ' + CONVERT(nvarchar(30), @VersionStoreGBThreshold) + N')' + CHAR(13)+CHAR(10) +
            N'Tempdb Total (GB): ' + CONVERT(nvarchar(30), @temp_total_gb) + CHAR(13)+CHAR(10) +
            N'Tempdb Free (GB):  ' + CONVERT(nvarchar(30), @temp_free_gb)  + CHAR(13)+CHAR(10) +
            N'Disk Free min (GB) on ' + ISNULL(@drivesCsv,N'?') + N': ' + CONVERT(nvarchar(30), @disk_free_gb) + N' (thr ' + CONVERT(nvarchar(30), @DiskFreeGBThreshold) + N')' + CHAR(13)+CHAR(10);

        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = @MailProfile,
            @recipients   = @MailRecipients,
            @subject      = @subject,
            @body         = @body;
    END
END
GO

/* 3) Views (DBA) */

-- 3.1 Long transactions (log)
CREATE OR ALTER VIEW dbo.vLongTransactions AS
SELECT
    l.LoggedAt,
    l.MinutesOpen,
    l.SessionID,
    l.TransactionID,
    l.DatabaseName,
    l.LoginName,
    l.HostName,
    l.ProgramName,
    l.WaitType,
    l.BlockingSession,
    LEFT(l.StatementText, 4000) AS StatementSample
FROM dbo.LongTransactionsLog AS l;
GO

-- 3.2 Oldest transaction in last 60 minutes
CREATE OR ALTER VIEW dbo.vOldestTransaction_60m AS
SELECT TOP(1) *
FROM dbo.vLongTransactions
WHERE LoggedAt > DATEADD(MINUTE, -60, SYSUTCDATETIME())
ORDER BY MinutesOpen DESC, LoggedAt DESC;
GO

-- 3.3 Autogrow last hour per db
CREATE OR ALTER VIEW dbo.vAutogrowLastHour AS
WITH last1h AS (
  SELECT DatabaseName, COUNT(*) AS events
  FROM dbo.FileGrowthLog
  WHERE EventTime > DATEADD(HOUR, -1, SYSUTCDATETIME())
  GROUP BY DatabaseName
)
SELECT * FROM last1h
ORDER BY events DESC;
GO

-- 3.4 Autogrow hourly trend (24h)
CREATE OR ALTER VIEW dbo.vAutogrowHourly_24h AS
WITH bucket AS (
  SELECT
    DATEADD(HOUR, DATEDIFF(HOUR, 0, EventTime), 0) AS hour_bucket,
    DatabaseName
  FROM dbo.FileGrowthLog
  WHERE EventTime > DATEADD(HOUR, -24, SYSUTCDATETIME())
)
SELECT hour_bucket, DatabaseName, COUNT(*) AS events
FROM bucket
GROUP BY hour_bucket, DatabaseName
ORDER BY hour_bucket DESC, events DESC;
GO

-- 3.5 Version Store 15min avg (GB) per db
CREATE OR ALTER VIEW dbo.vVersionStore15min AS
SELECT
    DatabaseId,
    DatabaseName,
    CAST(AVG(VersionStoreKB)/1024.0/1024.0 AS DECIMAL(18,2)) AS VS_GB_15min_avg
FROM dbo.VersionStoreUsageLog
WHERE CollectedAt > DATEADD(MINUTE, -15, SYSUTCDATETIME())
GROUP BY DatabaseId, DatabaseName
ORDER BY VS_GB_15min_avg DESC;
GO

-- 3.6 Version Store latest (GB)
CREATE OR ALTER VIEW dbo.vVersionStoreLatest AS
WITH x AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY DatabaseId ORDER BY CollectedAt DESC) AS rn
  FROM dbo.VersionStoreUsageLog
)
SELECT
  DatabaseId, DatabaseName,
  CAST(VersionStoreKB/1024.0/1024.0 AS DECIMAL(18,2)) AS VS_GB_latest,
  CollectedAt
FROM x
WHERE rn = 1
ORDER BY VS_GB_latest DESC;
GO

-- 3.7 DB file sizes (snapshot)
CREATE OR ALTER VIEW dbo.vDbFileSizes AS
SELECT
    DB_NAME(mf.database_id) AS DatabaseName,
    mf.type_desc            AS FileType,
    mf.name                 AS FileLogicalName,
    mf.physical_name,
    CAST(mf.size*8.0/1024.0 AS DECIMAL(18,2)) AS SizeMB,
    mf.max_size,
    mf.is_percent_growth,
    mf.growth
FROM sys.master_files AS mf
ORDER BY DatabaseName, FileType;
GO

-- 3.8 Top waits (since startup)
CREATE OR ALTER VIEW dbo.vWaitsTop AS
SELECT TOP(50)
    wait_type,
    wait_time_ms,
    signal_wait_time_ms,
    waiting_tasks_count
FROM sys.dm_os_wait_stats
WHERE wait_type NOT LIKE 'SLEEP%' AND wait_type NOT LIKE 'XE_TIMER%'
ORDER BY wait_time_ms DESC;
GO

-- 3.9 Tempdb Health - last row
CREATE OR ALTER VIEW dbo.vTempdbHealthLast AS
WITH x AS (
  SELECT *,
         ROW_NUMBER() OVER (ORDER BY LoggedAtUtc DESC) AS rn
  FROM dbo.TempdbHealthLog
)
SELECT
  LoggedAtUtc,
  VersionStoreGB,
  TempdbTotalGB,
  TempdbFreeGB,
  DiskFreeGB,
  DrivesCsv,
  ThresholdVS_GB,
  ThresholdDisk_GB,
  IsVSExceeded,
  IsDiskExceeded,
  Note
FROM x
WHERE rn = 1;
GO

-- 3.10 Tempdb Health - alerts (24h)
CREATE OR ALTER VIEW dbo.vTempdbHealthAlerts24h AS
SELECT
  LoggedAtUtc,
  VersionStoreGB,
  ThresholdVS_GB,
  DiskFreeGB,
  ThresholdDisk_GB,
  IsVSExceeded,
  IsDiskExceeded,
  DrivesCsv,
  Note
FROM dbo.TempdbHealthLog
WHERE LoggedAtUtc >= DATEADD(HOUR,-24,SYSUTCDATETIME())
  AND (IsVSExceeded = 1 OR IsDiskExceeded = 1)
ORDER BY LoggedAtUtc DESC;
GO

-- 3.11 Tempdb Health - hourly trend (24h)
CREATE OR ALTER VIEW dbo.vTempdbHealthHourly_24h AS
WITH b AS (
  SELECT
    DATEADD(HOUR, DATEDIFF(HOUR, 0, LoggedAtUtc), 0) AS hour_bucket,
    VersionStoreGB,
    TempdbTotalGB,
    TempdbFreeGB,
    DiskFreeGB
  FROM dbo.TempdbHealthLog
  WHERE LoggedAtUtc >= DATEADD(HOUR,-24,SYSUTCDATETIME())
)
SELECT
  hour_bucket,
  CAST(AVG(VersionStoreGB) AS DECIMAL(18,2)) AS VS_GB_avg,
  CAST(MAX(VersionStoreGB) AS DECIMAL(18,2)) AS VS_GB_max,
  CAST(AVG(TempdbTotalGB)  AS DECIMAL(18,2)) AS TempdbTotal_GB_avg,
  CAST(AVG(TempdbFreeGB)   AS DECIMAL(18,2)) AS TempdbFree_GB_avg,
  CAST(MIN(DiskFreeGB)     AS DECIMAL(18,2)) AS DiskFree_GB_min
FROM b
GROUP BY hour_bucket
ORDER BY hour_bucket DESC;
GO

PRINT 'DBA Tempdb Control — installation completed.';
