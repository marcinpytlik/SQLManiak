/*
  Walidacja po przeniesieniu dystrybucji na C.
*/
DECLARE @Publication sysname   = N'PubName';
DECLARE @Publisher sysname     = N'ServerC';
DECLARE @PublisherDb sysname   = N'TwojaBaza';
DECLARE @Subscriber sysname    = N'ServerB';
DECLARE @SubscriberDb sysname  = N'TwojaBazaB';

-- Undistributed = 0
EXEC sp_replmonitorsubscriptionpendingcmds
  @publisher = @Publisher, @publisher_db = @PublisherDb,
  @publication = @Publication, @subscriber = @Subscriber,
  @destination_db = @SubscriberDb;

-- Tracer token end-to-end
EXEC sp_posttracertoken @publication = @Publication;
EXEC sp_helptracertokenhistory @publication = @Publication;

-- Historia jobów (ostatnie błędy)
SELECT TOP 50 j.name, h.run_date, h.run_time, h.step_name, h.message
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
WHERE h.run_status <> 1
ORDER BY h.instance_id DESC;
