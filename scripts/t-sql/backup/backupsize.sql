USE msdb;
GO

IF OBJECT_ID('dbo.EstimateBackupSize', 'P') IS NOT NULL
    DROP PROCEDURE dbo.EstimateBackupSize;
GO

CREATE PROCEDURE dbo.EstimateBackupSize
    @DatabaseName sysname,
    @EstimatedBackupMB DECIMAL(18,2) OUTPUT,
    @CompressionRatioOverride DECIMAL(18,4) = NULL  -- opcjonalnie własny ratio
AS
BEGIN
    SET NOCOUNT ON;

    IF DB_ID(@DatabaseName) IS NULL
    BEGIN
        RAISERROR('EstimateBackupSize: Baza %s nie istnieje.', 16, 1, @DatabaseName);
        RETURN;
    END;

    DECLARE 
        @SQL       nvarchar(max),
        @UsedMB    DECIMAL(18,4),
        @Ratio     DECIMAL(18,4);

    -- Zbuduj cały dynamiczny SQL jako jeden string
    SET @SQL = N'
        DECLARE @UsedMB_local DECIMAL(18,4);

        SELECT @UsedMB_local =
            (total_page_count - unallocated_extent_page_count) * 8.0 / 1024.0
        FROM sys.dm_db_file_space_usage;

        SELECT @UsedMB_local AS UsedMB;
    ';

    DECLARE @UsedTable TABLE (UsedMB DECIMAL(18,4));

    -- Użyj dynamicznego USE + zapytanie
    SET @SQL = N'USE ' + QUOTENAME(@DatabaseName) + N';
    ' + @SQL;

    INSERT INTO @UsedTable(UsedMB)
    EXEC (@SQL);

    SELECT @UsedMB = UsedMB FROM @UsedTable;

    IF @UsedMB IS NULL
    BEGIN
        RAISERROR('EstimateBackupSize: Nie udało się pobrać używanej przestrzeni dla bazy %s.', 16, 1, @DatabaseName);
        RETURN;
    END;

    -- Współczynnik kompresji
    IF @CompressionRatioOverride IS NOT NULL
    BEGIN
        SET @Ratio = @CompressionRatioOverride;
    END
    ELSE
    BEGIN
        SELECT TOP 1
            @Ratio = CASE 
                        WHEN compressed_backup_size > 0 
                             THEN backup_size * 1.0 / compressed_backup_size
                        ELSE NULL
                     END
        FROM msdb.dbo.backupset
        WHERE database_name = @DatabaseName
          AND type = 'D'            -- FULL
          AND is_copy_only = 0
        ORDER BY backup_finish_date DESC;

        IF @Ratio IS NULL OR @Ratio <= 1
        BEGIN
            -- fallback, jeśli nie ma historii albo brak sensownych danych
            SET @Ratio = 2.5;
        END
    END;

    SET @EstimatedBackupMB = @UsedMB / @Ratio;
END
GO
USE msdb;
GO

IF OBJECT_ID('dbo.CheckBackupSpace', 'P') IS NOT NULL
    DROP PROCEDURE dbo.CheckBackupSpace;
GO

CREATE PROCEDURE dbo.CheckBackupSpace
    @DatabaseName             sysname,
    @BackupPath               nvarchar(4000),     -- np. 'E:\SQLBackups\MyDB\FULL'
    @RequiredMB               DECIMAL(18,2) OUTPUT,
    @FreeMB                   DECIMAL(18,2) OUTPUT,
    @CompressionRatioOverride DECIMAL(18,4) = NULL,
    @SafetyMarginPct          DECIMAL(5,2)  = 10.0,   -- zapas procentowy
    @MinFreeAfterMB           DECIMAL(18,2) = 10240.0 -- minimalne wolne miejsce po backupie (domyślnie 10 GB)
AS
BEGIN
    SET NOCOUNT ON;

    IF DB_ID(@DatabaseName) IS NULL
    BEGIN
        RAISERROR('CheckBackupSpace: Baza %s nie istnieje.', 16, 1, @DatabaseName);
        RETURN;
    END;

    IF @BackupPath IS NULL OR LEN(@BackupPath) < 3
    BEGIN
        RAISERROR('CheckBackupSpace: Nieprawidłowa ścieżka backupu.', 16, 1);
        RETURN;
    END;

    DECLARE 
        @DriveLetter CHAR(1),
        @dbid        int,
        @fileid      int,
        @available_bytes bigint;

    SET @DriveLetter = LEFT(@BackupPath, 1);

    -- 1) Szacowany rozmiar backupu
    EXEC dbo.EstimateBackupSize
        @DatabaseName             = @DatabaseName,
        @EstimatedBackupMB        = @RequiredMB OUTPUT,
        @CompressionRatioOverride = @CompressionRatioOverride;

    -- Zapas bezpieczeństwa
    SET @RequiredMB = @RequiredMB * (1.0 + @SafetyMarginPct / 100.0);

    -- 2) Wolne miejsce na woluminie, na którym leży @BackupPath
    SELECT TOP 1 
        @dbid   = database_id,
        @fileid = file_id
    FROM sys.master_files
    WHERE physical_name LIKE @DriveLetter + ':%';

    IF @dbid IS NULL
    BEGIN
        RAISERROR('CheckBackupSpace: Nie znaleziono żadnego pliku na dysku %s:. Nie można oszacować wolnego miejsca.', 16, 1, @DriveLetter);
        RETURN;
    END;

    SELECT @available_bytes = vs.available_bytes
    FROM sys.dm_os_volume_stats(@dbid, @fileid) AS vs;

    IF @available_bytes IS NULL
    BEGIN
        RAISERROR('CheckBackupSpace: Nie udało się pobrać informacji o wolnym miejscu na dysku %s:.', 16, 1, @DriveLetter);
        RETURN;
    END;

    SET @FreeMB = @available_bytes / 1024.0 / 1024.0;

    -- 3) Logika decyzji
    IF (@FreeMB - @RequiredMB) < @MinFreeAfterMB
    BEGIN
        DECLARE @Msg nvarchar(4000);

        SET @Msg = N'CheckBackupSpace: Za mało miejsca na backup bazy ' 
                 + QUOTENAME(@DatabaseName)
                 + N'. Szacowany rozmiar (z zapasem): '
                 + CONVERT(varchar(50), @RequiredMB)
                 + N' MB, wolne: '
                 + CONVERT(varchar(50), @FreeMB)
                 + N' MB, wymagane wolne po backupie: '
                 + CONVERT(varchar(50), @MinFreeAfterMB)
                 + N' MB.';

        RAISERROR(@Msg, 16, 1);
        RETURN;
    END;

    -- Info diagnostyczne (przydatne w historii joba)
    PRINT CONCAT(
        'CheckBackupSpace OK dla bazy ', @DatabaseName,
        '. Estimated (with margin): ', CONVERT(varchar(50), @RequiredMB), ' MB, Free: ',
        CONVERT(varchar(50), @FreeMB), ' MB, MinFreeAfter: ',
        CONVERT(varchar(50), @MinFreeAfterMB), ' MB.'
    );
END
GO
-- test
SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(4000)) AS DefaultBackupDir;

USE msdb;
GO

DECLARE 
    @RequiredMB DECIMAL(18,2),
    @FreeMB     DECIMAL(18,2);

EXEC dbo.CheckBackupSpace
    @DatabaseName = N'AdventureWorksDW2020',                     -- ← PODMIEŃ
    @BackupPath   = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup',  -- ← PODMIEŃ
    @RequiredMB   = @RequiredMB OUTPUT,
    @FreeMB       = @FreeMB OUTPUT;

SELECT 
    EstimatedBackupMB = @RequiredMB,
    FreeSpaceMB       = @FreeMB;
USE msdb;
GO

DECLARE @job_id uniqueidentifier;

------------------------------------------------------------
-- 1. Tworzenie joba
------------------------------------------------------------
EXEC sp_add_job 
    @job_name        = N'Backup FULL z kontrolą miejsca - AdventureWorksDW2020',
    @enabled         = 1,
    @description     = N'Backup FULL AdventureWorksDW2020 z wcześniejszym sprawdzeniem wolnego miejsca na dysku.',
    @category_name   = N'Database Maintenance',
    @job_id          = @job_id OUTPUT;
GO

------------------------------------------------------------
-- 2. Krok 1 – CheckBackupSpace
------------------------------------------------------------
EXEC sp_add_jobstep
    @job_name             = N'Backup FULL z kontrolą miejsca - AdventureWorksDW2020',
    @step_name            = N'Check backup space',
    @subsystem            = N'TSQL',
    @database_name        = N'msdb',
    @on_success_action    = 3,  -- Go to next step
    @on_fail_action       = 2,  -- Quit with failure
    @command = N'
DECLARE 
    @RequiredMB DECIMAL(18,2),
    @FreeMB     DECIMAL(18,2);

EXEC dbo.CheckBackupSpace
    @DatabaseName = N''AdventureWorksDW2020'',
    @BackupPath   = N''C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup'',
    @RequiredMB   = @RequiredMB OUTPUT,
    @FreeMB       = @FreeMB OUTPUT;

PRINT CONCAT(
    ''[CheckBackupSpace] AdventureWorksDW2020 – Estimated (with margin): '',
    CONVERT(varchar(50), @RequiredMB), '' MB, Free: '',
    CONVERT(varchar(50), @FreeMB), '' MB.'');
';
GO

------------------------------------------------------------
-- 3. Krok 2 – Backup FULL
------------------------------------------------------------
EXEC sp_add_jobstep
    @job_name             = N'Backup FULL z kontrolą miejsca - AdventureWorksDW2020',
    @step_name            = N'Backup FULL database',
    @subsystem            = N'TSQL',
    @database_name        = N'master',
    @on_success_action    = 1,  -- Quit with success
    @on_fail_action       = 2,  -- Quit with failure
    @command = N'
DECLARE @BackupFile nvarchar(4000);

SET @BackupFile = N''C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\AdventureWorksDW2020_FULL_'' 
    + CONVERT(char(8), GETDATE(), 112) 
    + N''_'' 
    + REPLACE(CONVERT(char(8), GETDATE(), 108), '':'', '''')
    + N''.bak'';

PRINT ''[Backup] Plik: '' + @BackupFile;

BACKUP DATABASE [AdventureWorksDW2020]
TO DISK = @BackupFile
WITH 
    COMPRESSION,
    CHECKSUM,
    STATS = 5;
';
GO

------------------------------------------------------------
-- 4. Harmonogram – codziennie 23:00
------------------------------------------------------------
EXEC sp_add_schedule
    @schedule_name     = N'Codzienny backup FULL AdventureWorksDW2020 23:00',
    @freq_type         = 4,          -- daily
    @freq_interval     = 1,
    @active_start_time = 230000,     -- 23:00:00
    @schedule_id       = NULL;
GO

EXEC sp_attach_schedule
    @job_name      = N'Backup FULL z kontrolą miejsca - AdventureWorksDW2020',
    @schedule_name = N'Codzienny backup FULL AdventureWorksDW2020 23:00';
GO

------------------------------------------------------------
-- 5. Przypięcie joba do serwera
------------------------------------------------------------
EXEC sp_add_jobserver
    @job_name    = N'Backup FULL z kontrolą miejsca - AdventureWorksDW2020',
    @server_name = N'(local)';   -- podmień jeśli nie lokalnie
GO
