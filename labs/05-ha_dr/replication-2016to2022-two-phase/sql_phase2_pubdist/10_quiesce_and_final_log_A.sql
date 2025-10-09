EXEC msdb.dbo.sp_stop_job @job_name=N'Log Reader Agent ServerA-TwojaBaza'; BACKUP LOG [TwojaBaza] TO DISK=N'\\A\Backups\TwojaBaza_p2_FINAL_LOG.trn' WITH INIT, COMPRESSION;
