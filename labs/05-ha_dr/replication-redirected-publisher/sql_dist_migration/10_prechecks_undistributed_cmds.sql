/*
  PRECHECK na A (stary dystrybutor):
  - Potwierdź brak zaległych komend.
  - Zatrzymaj agenty powiązane z publikacją.
*/
DECLARE @Publisher sysname     = N'ServerC';     -- po cutoverze realny publisher to C
DECLARE @PublisherDb sysname   = N'TwojaBaza';
DECLARE @Publication sysname   = N'PubName';
DECLARE @Subscriber sysname    = N'ServerB';
DECLARE @SubscriberDb sysname  = N'TwojaBazaB';

-- 1) Zaległe komendy
EXEC sp_replmonitorsubscriptionpendingcmds
  @publisher = @Publisher, @publisher_db = @PublisherDb,
  @publication = @Publication, @subscriber = @Subscriber,
  @destination_db = @SubscriberDb;

-- 2) Stop agentów na A (push; dostosuj nazwy jeżeli inne)
BEGIN TRY
  EXEC msdb.dbo.sp_stop_job @job_name = N'Log Reader Agent ' + @Publisher + N'-' + @PublisherDb;
END TRY BEGIN CATCH END CATCH;

BEGIN TRY
  EXEC msdb.dbo.sp_stop_job @job_name = N'Distribution Agent ' + @Publisher + N'-' + @PublisherDb + N'-' + @Subscriber + N'-' + @SubscriberDb;
END TRY BEGIN CATCH END CATCH;
