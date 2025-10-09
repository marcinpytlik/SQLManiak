/*
  OKNO CIĘCIA na A:
  1) Wstrzymaj ruch do bazy.
  2) Zatrzymaj agenty replikacji dla tej publikacji (Log Reader + Distribution).
  3) Wykonaj FINALNY LOG BACKUP.
*/
DECLARE @Db sysname           = N'TwojaBaza';
DECLARE @Publisher sysname    = N'ServerA';
DECLARE @Publication sysname  = N'PubName';
DECLARE @Subscriber sysname   = N'ServerB';
DECLARE @SubscriberDb sysname = N'TwojaBazaB';

DECLARE @FinalLog nvarchar(4000) = N'D:\Backups\' + @Db + N'_FINAL_LOG.trn';

-- 1) Stop agentów (po nazwach jobów – dopasuj nazwy jeśli inne)
EXEC msdb.dbo.sp_stop_job @job_name = N'Log Reader Agent ' + @Publisher + N'-' + @Db;
EXEC msdb.dbo.sp_stop_job @job_name = N'Distribution Agent ' + @Publisher + N'-' + @Db + N'-' + @Subscriber + N'-' + @SubscriberDb;

-- 2) Finalny backup logu (brak aktywności w bazie!)
BACKUP LOG @Db TO DISK = @FinalLog WITH INIT, COMPRESSION, STATS = 5;

-- 3) (opcjonalnie) Potwierdź brak zaległych komend
-- EXEC sp_replmonitorsubscriptionpendingcmds
--   @publisher = @Publisher, @publisher_db = @Db,
--   @publication = @Publication, @subscriber = @Subscriber,
--   @destination_db = @SubscriberDb;
