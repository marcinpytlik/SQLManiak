
-- 07_SnapshotFullErrorTest.sql
-- Cel: pokazać zachowanie snapshotu przy braku miejsca (OS error 112) i przejściu w stan SUSPECT.
-- Uwaga: T-SQL nie może "wypełnić dysku". Ten skrypt:
--   1) wykrywa ścieżkę pliku snapshotu,
--   2) raportuje wolne miejsce na woluminie,
--   3) wykonuje pętle masowych modyfikacji, które generują copy-on-write,
--   4) po każdej turze sprawdza stan snapshotu (sys.databases.state_desc).
-- Aby realnie doprowadzić do SUSPECT, ogranicz miejsce na woluminie snapshotu (np. mały dysk VHD).

:setvar DatabaseName SnapshotDemoDB
:setvar SnapshotName SnapshotDemoDB_SS

USE master;
IF DB_ID('$(SnapshotName)') IS NULL
BEGIN
    RAISERROR('Snapshot $(SnapshotName) nie istnieje. Uruchom 02_CreateSnapshot.sql', 16, 1);
    RETURN;
END

PRINT '>> Parametry:';
SELECT DB_NAME() AS context_db, '$(DatabaseName)' AS DatabaseName, '$(SnapshotName)' AS SnapshotName;

PRINT '>> 1) Wykrywanie pliku snapshotu i woluminu';
DECLARE @snap_file nvarchar(260);
SELECT @snap_file = mf.physical_name
FROM sys.master_files AS mf
WHERE DB_NAME(mf.database_id) = '$(SnapshotName)' AND mf.type_desc = 'ROWS';

SELECT [snapshot_file] = @snap_file;

-- Wydobycie litery dysku (NTFS)
DECLARE @drive nvarchar(10) = LEFT(@snap_file, 2); -- np. 'D:'
PRINT '>> Wolumin snapshotu: ' + @drive;

-- Wolne miejsce wg sys.dm_os_volume_stats (wymaga VIEW SERVER STATE)
SELECT DISTINCT
       vs.volume_mount_point,
       vs.file_system_type,
       vs.logical_volume_name,
       total_bytes = vs.total_bytes/1024/1024/1024.0,
       available_bytes = vs.available_bytes/1024/1024/1024.0,
       available_pct = (vs.available_bytes*100.0)/vs.total_bytes
FROM sys.master_files AS mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs
WHERE vs.volume_mount_point = @drive + '\';

PRINT '>> 2) Rozmiary plików (baza i snapshot)';
SELECT DB_NAME(mf.database_id) AS db, mf.name, mf.type_desc, mf.physical_name,
       size_MB = mf.size*8.0/1024
FROM sys.master_files AS mf
WHERE DB_NAME(mf.database_id) IN ('$(DatabaseName)', '$(SnapshotName)')
ORDER BY db, type_desc, name;

PRINT '>> 3) Generowanie dużych modyfikacji (pętle), aby snapshot rósł';
DECLARE @i int = 1, @max int = 50; -- zwiększ @max jeśli masz mały wolumen

WHILE @i <= @max
BEGIN
    BEGIN TRY
        PRINT CONCAT('>> Tura #', @i, ' — UPDATE/DELETE/INSERT...');
        EXEC(N'
            USE [$(DatabaseName)];
            -- Masowy UPDATE ~30%
            UPDATE s SET Amount = Amount * 1.02 WHERE (Id + '+CAST(@i as nvarchar(10))+') % 10 IN (0,1,2);
            CHECKPOINT;

            -- DELETE ~5%
            DELETE FROM dbo.Sales WHERE (Id + '+CAST(@i as nvarchar(10))+') % 20 = 3;
            CHECKPOINT;

            -- INSERT 100k
            ;WITH gen AS
            (
              SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
              FROM sys.all_objects a CROSS JOIN sys.all_objects b
            )
            INSERT INTO dbo.Sales(CustomerId, OrderDate, Amount, Payload)
            SELECT (n % 100000) + 1,
                   DATEADD(minute, -n, SYSUTCDATETIME()),
                   (n % 10000) * 0.01,
                   REPLICATE(''Z'', 200)
            FROM gen;
            CHECKPOINT;
        ');

        -- Raport po turze
        PRINT '>> Rozmiary po turze:';
        SELECT DB_NAME(mf.database_id) AS db, mf.name, mf.type_desc, mf.physical_name,
               size_MB = mf.size*8.0/1024
        FROM sys.master_files AS mf
        WHERE DB_NAME(mf.database_id) IN ('$(DatabaseName)', '$(SnapshotName)')
        ORDER BY db, type_desc, name;

        -- Stan snapshotu
        DECLARE @state_desc nvarchar(60);
        SELECT @state_desc = state_desc FROM sys.databases WHERE name = '$(SnapshotName)';
        PRINT '>> Stan snapshotu: ' + @state_desc;

        IF @state_desc = 'SUSPECT'
        BEGIN
            PRINT '>> Snapshot jest SUSPECT. Koniec testu.';
            BREAK;
        END

        SET @i += 1;
    END TRY
    BEGIN CATCH
        PRINT '!! Wyjątek podczas tury ' + CAST(@i AS nvarchar(10));
        PRINT ERROR_MESSAGE();
        -- Jeśli to błąd 823/824 lub OS 112 — snapshot mógł już paść.
        SELECT name, state_desc FROM sys.databases WHERE name IN ('$(DatabaseName)', '$(SnapshotName)');
        BREAK;
    END CATCH
END

PRINT '>> Test zakończony. Jeśli snapshot nie jest SUSPECT, prawdopodobnie nie zabrakło miejsca na woluminie.';
