/*
  Monitoring i diagnostyka po przełączeniu.
*/
DECLARE @Publication sysname   = N'PubName';
DECLARE @Publisher sysname     = N'ServerC';       -- nowy realny publisher
DECLARE @PublisherDb sysname   = N'TwojaBaza';
DECLARE @Subscriber sysname    = N'ServerB';
DECLARE @SubscriberDb sysname  = N'TwojaBazaB';

-- Zaległe komendy
EXEC sp_replmonitorsubscriptionpendingcmds
  @publisher = @Publisher, @publisher_db = @PublisherDb,
  @publication = @Publication, @subscriber = @Subscriber,
  @destination_db = @SubscriberDb;

-- Tracer token (latency end-to-end)
EXEC sp_posttracertoken @publication = @Publication;
EXEC sp_helptracertokenhistory @publication = @Publication;

-- Historia jobów (ostatnie błędy)
SELECT TOP 50 j.name, h.run_date, h.run_time, h.step_name, h.message
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
WHERE h.run_status <> 1
ORDER BY h.instance_id DESC;

-- Ping replikacji
EXEC sp_replcounters;
