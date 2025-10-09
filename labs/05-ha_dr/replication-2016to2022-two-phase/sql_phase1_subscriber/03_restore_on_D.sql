RESTORE DATABASE [TwojaBaza] FROM DISK=N'\\A\Backups\TwojaBaza_p1_full.bak' WITH NORECOVERY, REPLACE; RESTORE LOG [TwojaBaza] FROM DISK=N'\\A\Backups\TwojaBaza_p1_log.trn' WITH RECOVERY;
