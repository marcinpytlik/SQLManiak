BACKUP DATABASE [TwojaBaza] TO DISK=N'\\A\Backups\TwojaBaza_p1_full.bak' WITH COPY_ONLY, INIT, COMPRESSION; BACKUP LOG [TwojaBaza] TO DISK=N'\\A\Backups\TwojaBaza_p1_log.trn' WITH INIT, COMPRESSION;
