/*
  Wstępne backupy na A (przed cięciem) — FULL + testowe LOG, aby potwierdzić ścieżki i czasy.
*/
DECLARE @Db sysname = N'TwojaBaza';
DECLARE @Full nvarchar(4000) = N'D:\Backups\' + @Db + N'_pre_full.bak';
DECLARE @Log  nvarchar(4000) = N'D:\Backups\' + @Db + N'_pre_log.trn';

BACKUP DATABASE @Db TO DISK = @Full WITH INIT, COPY_ONLY, COMPRESSION, STATS = 5;
BACKUP LOG      @Db TO DISK = @Log  WITH INIT, COMPRESSION, STATS = 5;

-- Weryfikacja backupów
RESTORE VERIFYONLY FROM DISK = @Full;
RESTORE VERIFYONLY FROM DISK = @Log;
