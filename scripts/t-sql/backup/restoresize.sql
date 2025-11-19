USE msdb;
GO

IF OBJECT_ID('dbo.EstimateRestoreSpace', 'P') IS NOT NULL
    DROP PROCEDURE dbo.EstimateRestoreSpace;
GO

CREATE PROCEDURE dbo.EstimateRestoreSpace
(
    @BackupFilePath    nvarchar(4000),         -- pełna ścieżka do backupu .bak
    @SafetyMarginPct   decimal(5,2) = 10.0     -- margines bezpieczeństwa w %
)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '>>> Estymacja miejsca dla RESTORE z backupu: ' + @BackupFilePath;
    PRINT '>>> Margines bezpieczeństwa: ' + CAST(@SafetyMarginPct AS nvarchar(30)) + N'%';

    IF OBJECT_ID('tempdb..#FileList') IS NOT NULL DROP TABLE #FileList;
    IF OBJECT_ID('tempdb..#Drives')   IS NOT NULL DROP TABLE #Drives;

    -- Tabela pod wynik RESTORE FILELISTONLY (layout zgodny z nowszymi wersjami)
    CREATE TABLE #FileList
    (
        LogicalName         nvarchar(128),
        PhysicalName        nvarchar(260),
        Type                char(1),
        FileGroupName       nvarchar(128),
        Size                numeric(20,0),
        MaxSize             numeric(20,0),
        FileId              int,
        CreateLSN           numeric(25,0),
        DropLSN             numeric(25,0),
        UniqueId            uniqueidentifier,
        ReadOnlyLSN         numeric(25,0),
        ReadWriteLSN        numeric(25,0),
        BackupSizeInBytes   bigint,
        SourceBlockSize     int,
        FileGroupId         int,
        LogGroupGUID        uniqueidentifier NULL,
        DifferentialBaseLSN numeric(25,0) NULL,
        DifferentialBaseGUID uniqueidentifier NULL,
        IsReadOnly          bit,
        IsPresent           bit,
        TDEThumbprint       varbinary(32) NULL,
        SnapshotUrl         nvarchar(360) NULL
    );

    DECLARE @sql nvarchar(max) =
        N'RESTORE FILELISTONLY FROM DISK = N''' +
        REPLACE(@BackupFilePath, '''', '''''') + N'''';

    INSERT INTO #FileList
    EXEC(@sql);

    -- Zbieramy wolne miejsce na dyskach (MB)
    CREATE TABLE #Drives
    (
        DriveLetter char(1),
        FreeMB      int
    );

    INSERT INTO #Drives
    EXEC xp_fixeddrives;  -- wymaga uprawnień sysadmin

    ;WITH FilesWithDrive AS
    (
        SELECT
            LogicalName,
            PhysicalName,
            Type,
            SizePages = Size,
            SizeMB   = Size * 8.0 / 1024.0,  -- Size w stronach 8 KB
            DriveLetter = UPPER(LEFT(PhysicalName, 1))
        FROM #FileList
        WHERE IsPresent = 1
    ),
    RequiredPerDrive AS
    (
        SELECT
            DriveLetter,
            RequiredMB          = SUM(SizeMB),
            RequiredWithMarginMB = SUM(SizeMB) * (1.0 + (@SafetyMarginPct / 100.0))
        FROM FilesWithDrive
        GROUP BY DriveLetter
    )
    SELECT
        r.DriveLetter,
        r.RequiredMB,
        r.RequiredWithMarginMB,
        d.FreeMB,
        CanRestore = CASE 
                        WHEN d.FreeMB IS NULL THEN NULL   -- brak takiego dysku
                        WHEN d.FreeMB >= r.RequiredWithMarginMB THEN 1 
                        ELSE 0 
                     END
    INTO #Result
    FROM RequiredPerDrive r
    LEFT JOIN #Drives d
        ON d.DriveLetter = r.DriveLetter;

    -- Wynik szczegółowy
    SELECT
        DriveLetter,
        RequiredMB          = ROUND(RequiredMB, 2),
        RequiredWithMarginMB = ROUND(RequiredWithMarginMB, 2),
        FreeMB,
        CanRestore
    FROM #Result
    ORDER BY DriveLetter;

    -- Podsumowanie globalne
    DECLARE @AllOk bit;

    SELECT 
        @AllOk = CASE 
                    WHEN EXISTS (
                        SELECT 1 
                        FROM #Result 
                        WHERE CanRestore = 0 OR CanRestore IS NULL
                    )
                        THEN 0
                    ELSE 1
                  END;

    PRINT '---------------------------------------------------------';
    PRINT 'PODSUMOWANIE:';
    IF @AllOk = 1
        PRINT '✅ Według estymacji: na wszystkich dyskach jest wystarczająco miejsca (z marginesem).';
    ELSE
        PRINT '❌ Według estymacji: na co najmniej jednym dysku brakuje miejsca (z marginesem) lub dysk nie istnieje.';

    SELECT @AllOk AS CanRestoreWithMargin;
END
GO
