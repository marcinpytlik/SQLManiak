# SQL Agent Job — Tempdb Health Alert (Version Store + Disk Free)

## 🎯 Cel
- Alarmować, gdy:
  - `Version Store` w **tempdb** przekroczy próg (GB),
  - wolne miejsce na dysku z plikami **tempdb** spadnie poniżej progu (GB).
- Logować pomiary do tabeli w bazie **DBA**.

---

## 📦 Skład
- Tabela: `DBA.dbo.TempdbHealthLog`
- Procedura: `DBA.dbo.Alert_TempdbHealth`
- Job: `DEV: Tempdb Health Alert` (co 10 min)
- (Opcjonalnie) e-mail przez Database Mail

---

## 🛠️ Deployment — uruchom cały blok T-SQL

```sql
/* 0) Baza administracyjna */
IF DB_ID('DBA') IS NULL
BEGIN
    PRINT 'Tworzę bazę DBA...';
    EXEC('CREATE DATABASE DBA');
END
GO

USE DBA;
GO

/* 1) Tabela logów */
IF OBJECT_ID('dbo.TempdbHealthLog') IS NULL
BEGIN
    CREATE TABLE dbo.TempdbHealthLog
    (
        Id               BIGINT IDENTITY(1,1) PRIMARY KEY,
        LoggedAtUtc      DATETIME2 NOT NULL CONSTRAINT DF_TempdbHealth_LoggedAtUtc DEFAULT SYSUTCDATETIME(),
        VersionStoreGB   DECIMAL(18,2) NOT NULL,
        TempdbTotalGB    DECIMAL(18,2) NOT NULL,
        TempdbFreeGB     DECIMAL(18,2) NOT NULL,      -- free inside files (unallocated)
        DiskFreeGB       DECIMAL(18,2) NOT NULL,      -- min free across volumes used by tempdb
        DrivesCsv        NVARCHAR(200) NULL,          -- e.g. 'T;U'
        ThresholdVS_GB   DECIMAL(18,2) NOT NULL,
        ThresholdDisk_GB DECIMAL(18,2) NOT NULL,
        IsVSExceeded     BIT NOT NULL,
        IsDiskExceeded   BIT NOT NULL,
        Note             NVARCHAR(4000) NULL
    );
    CREATE INDEX IX_TempdbHealth_LoggedAtUtc ON dbo.TempdbHealthLog(LoggedAtUtc);
END
GO

/* 2) Procedura alertowa */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROC dbo.Alert_TempdbHealth
    @VersionStoreGBThreshold DECIMAL(18,2) = 10.0,      -- próg VS
    @DiskFreeGBThreshold     DECIMAL(18,2) = 20.0,      -- próg wolnego miejsca na dysku
    @MailProfile             SYSNAME = NULL,            -- nazwa profilu Database Mail
    @MailRecipients          NVARCHAR(4000) = NULL      -- lista adresów ;-separated
AS
BEGIN
    SET NOCOUNT ON;

    /* 2.1 Pomiary tempdb */
    DECLARE @vs_gb DECIMAL(18,2)
          , @temp_total_gb DECIMAL(18,2)
          , @temp_free_gb  DECIMAL(18,2);

    SELECT
        @vs_gb = CAST(SUM(version_store_reserved_page_count)*8.0/1024.0/1024.0 AS DECIMAL(18,2))
    FROM tempdb.sys.dm_db_file_space_usage;

    SELECT
        @temp_total_gb = CAST(SUM(size)*8.0/1024.0/1024.0 AS DECIMAL(18,2))
    FROM tempdb.sys.database_files;

    /* unallocated extents inside tempdb files */
    SELECT
        @temp_free_gb = CAST(SUM(unallocated_extent_page_count)*8.0/1024.0/1024.0 AS DECIMAL(18,2))
    FROM tempdb.sys.dm_db_file_space_usage;

    /* 2.2 Wolne miejsce na woluminach tempdb */
    DECLARE @drives TABLE(Drive NVARCHAR(2) PRIMARY KEY);
    INSERT INTO @drives(Drive)
    SELECT DISTINCT UPPER(LEFT(physical_name,2))
    FROM tempdb.sys.database_files
    WHERE physical_name LIKE '[A-Z]%'  -- lokalne ścieżki w formacie C:\...
      AND LEFT(physical_name,2) LIKE '[A-Z]:';

    /* xp_fixeddrives: wymaga sysadmin */
    DECLARE @disk TABLE(Drive NVARCHAR(2) PRIMARY KEY, FreeMB BIGINT);
    INSERT INTO @disk(Drive, FreeMB)
    EXEC master..xp_fixeddrives;

    DECLARE @drivesCsv NVARCHAR(200) =
      STUFF( (SELECT ';'+d.Drive FROM @drives d FOR XML PATH(''), TYPE).value('.','nvarchar(max)'), 1, 1, '');

    DECLARE @disk_free_gb DECIMAL(18,2) =
    (
        SELECT CAST(MIN(CAST(x.FreeMB AS DECIMAL(18,2))/1024.0) AS DECIMAL(18,2))
        FROM @drives dv
        JOIN @disk   x  ON x.Drive = dv.Drive
    );

    IF @disk_free_gb IS NULL SET @disk_free_gb = -1;  -- gdy brak dopasowania (np. SMB, Linux paths)

    /* 2.3 Progi */
    DECLARE @isVSExceeded   BIT = CASE WHEN @vs_gb        >= @VersionStoreGBThreshold THEN 1 ELSE 0 END;
    DECLARE @isDiskExceeded BIT = CASE WHEN @disk_free_gb >= 0 AND @disk_free_gb <= @DiskFreeGBThreshold THEN 1 ELSE 0 END;

    /* 2.4 Zapis do logu */
    INSERT INTO dbo.TempdbHealthLog
    (
        VersionStoreGB, TempdbTotalGB, TempdbFreeGB, DiskFreeGB, DrivesCsv,
        ThresholdVS_GB, ThresholdDisk_GB, IsVSExceeded, IsDiskExceeded, Note
    )
    VALUES
    (
        @vs_gb, @temp_total_gb, @temp_free_gb, @disk_free_gb, @drivesCsv,
        @VersionStoreGBThreshold, @DiskFreeGBThreshold, @isVSExceeded, @isDiskExceeded,
        CASE WHEN @disk_free_gb < 0 THEN N'xp_fixeddrives nie zwrócił woluminu dla tempdb (nietypowa ścieżka?).' ELSE NULL END
    );

    /* 2.5 E-mail (opcjonalnie) */
    IF (@isVSExceeded = 1 OR @isDiskExceeded = 1)
       AND @MailProfile IS NOT NULL AND @MailRecipients IS NOT NULL
    BEGIN
        DECLARE @subject NVARCHAR(255) = N'[SQL][Tempdb] Alert: ' +
            CASE WHEN @isVSExceeded=1 THEN N'VersionStore ' ELSE N'' END +
            CASE WHEN @isDiskExceeded=1 THEN N'DiskFree '     ELSE N'' END;

        DECLARE @body NVARCHAR(MAX) =
            N'UTC: ' + CONVERT(nvarchar(30), SYSUTCDATETIME(), 126) + CHAR(13)+CHAR(10) +
            N'VersionStoreGB: ' + CONVERT(nvarchar(30), @vs_gb) + N' (threshold ' + CONVERT(nvarchar(30), @VersionStoreGBThreshold) + N')' + CHAR(13)+CHAR(10) +
            N'TempdbTotalGB:  ' + CONVERT(nvarchar(30), @temp_total_gb) + CHAR(13)+CHAR(10) +
            N'TempdbFreeGB:   ' + CONVERT(nvarchar(30), @temp_free_gb) + CHAR(13)+CHAR(10) +
            N'DiskFreeGB(min across ' + ISNULL(@drivesCsv,N'?') + N'): ' + CONVERT(nvarchar(30), @disk_free_gb) + N' (threshold ' + CONVERT(nvarchar(30), @DiskFreeGBThreshold) + N')' + CHAR(13)+CHAR(10);

        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = @MailProfile,
            @recipients   = @MailRecipients,
            @subject      = @subject,
            @body         = @body;
    END
END
GO

/* 3) Job SQL Agent */
USE msdb;
GO
DECLARE @job_id UNIQUEIDENTIFIER, @schedule_id INT, @today INT = CONVERT(INT, CONVERT(CHAR(8), GETDATE(), 112));

EXEC msdb.dbo.sp_add_job
    @job_name = N'DEV: Tempdb Health Alert',
    @enabled = 1,
    @description = N'Monitoruje Version Store i wolne miejsce na dyskach tempdb; loguje i wysyła mail (opcjonalnie).',
    @owner_login_name = N'sa',
    @notify_level_eventlog = 2,
    @job_id = @job_id OUTPUT;

-- Krok 1: bez e-maila (domyślnie)
EXEC msdb.dbo.sp_add_jobstep
    @job_id = @job_id,
    @step_id = 1,
    @step_name = N'Check (no email)',
    @subsystem = N'TSQL',
    @database_name = N'DBA',
    @command = N'EXEC dbo.Alert_TempdbHealth
                     @VersionStoreGBThreshold = 10,
                     @DiskFreeGBThreshold     = 20,
                     @MailProfile             = NULL,
                     @MailRecipients          = NULL;',
    @on_success_action = 1,
    @on_fail_action = 2;

-- (Opcjonalny) Krok 2: z e-mailem – włącz po skonfigurowaniu Database Mail
EXEC msdb.dbo.sp_add_jobstep
    @job_id = @job_id,
    @step_id = 2,
    @step_name = N'Check (+email)',
    @subsystem = N'TSQL',
    @database_name = N'DBA',
    @command = N'EXEC dbo.Alert_TempdbHealth
                     @VersionStoreGBThreshold = 10,
                     @DiskFreeGBThreshold     = 20,
                     @MailProfile             = N''YourMailProfile'',
                     @MailRecipients          = N''you@example.com;team@example.com'';',
    @on_success_action = 1,
    @on_fail_action = 2,
    @enabled = 0;  -- odblokuj gdy mail jest gotowy

-- Harmonogram co 10 minut
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Every 10 minutes (Tempdb Health)',
    @enabled = 1,
    @freq_type = 4,              -- daily
    @freq_interval = 1,
    @freq_subday_type = 4,       -- minutes
    @freq_subday_interval = 10,
    @active_start_date = @today,
    @active_start_time = 000000,
    @schedule_id = @schedule_id OUTPUT;

EXEC msdb.dbo.sp_attach_schedule @job_id = @job_id, @schedule_id = @schedule_id;
EXEC msdb.dbo.sp_add_jobserver  @job_id = @job_id, @server_name = N'(LOCAL)';
GO
```
