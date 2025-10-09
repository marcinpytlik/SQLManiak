/*
  RESTORE na C:
  - Przywróć FULL WITH NORECOVERY (z A).
  - Przywróć wszystkie LOG (z A) WITH NORECOVERY.
  - Ostatni LOG: WITH KEEP_REPLICATION, RECOVERY.
*/
DECLARE @Db sysname = N'TwojaBaza';

-- Ścieżki do backupów (przenieś pliki z A na C)
DECLARE @Full nvarchar(4000) = N'D:\Backups\' + @Db + N'_pre_full.bak';
DECLARE @LogPre nvarchar(4000) = N'D:\Backups\' + @Db + N'_pre_log.trn';
DECLARE @FinalLog nvarchar(4000) = N'D:\Backups\' + @Db + N'_FINAL_LOG.trn';

-- FULL
RESTORE DATABASE @Db FROM DISK = @Full WITH NORECOVERY, REPLACE, STATS = 5;

-- LOG(i) próbne
RESTORE LOG @Db FROM DISK = @LogPre WITH NORECOVERY, STATS = 5;

-- Ostatni LOG: KEEP_REPLICATION + RECOVERY
RESTORE LOG @Db FROM DISK = @FinalLog WITH KEEP_REPLICATION, RECOVERY, STATS = 5;

-- Podniesienie metadanych replikacji (jeśli potrzebne po wersji)
EXEC sp_vupgrade_replication;

-- Walidacja podstawowa
SELECT is_published, is_merge_published, is_distributor
FROM sys.databases WHERE name = @Db;
