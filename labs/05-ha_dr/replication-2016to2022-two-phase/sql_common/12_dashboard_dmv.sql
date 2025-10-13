/*
  Mini-dashboard dla replikacji (szybki status)
*/
DECLARE @Publication sysname = N'PubName';
DECLARE @Publisher sysname = N'ServerC';
DECLARE @PublisherDb sysname = N'TwojaBaza';
DECLARE @Subscriber sysname = N'ServerD';
DECLARE @SubscriberDb sysname = N'TwojaBaza';

PRINT '=== Publikacja ===';
EXEC sp_helppublication @publication=@Publication;

PRINT '=== Undistributed Commands ===';
EXEC sp_replmonitorsubscriptionpendingcmds
  @publisher=@Publisher, @publisher_db=@PublisherDb,
  @publication=@Publication, @subscriber=@Subscriber, @destination_db=@SubscriberDb;

PRINT '=== Tracer token (nowy + historia) ===';
EXEC sp_posttracertoken @publication=@Publication;
EXEC sp_helptracertokenhistory @publication=@Publication;

PRINT '=== Job errors (msdb) ===';
SELECT TOP 50 j.name, h.run_date, h.run_time, h.step_name, h.message
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
WHERE j.name LIKE '%Agent%' AND h.run_status <> 1
ORDER BY h.instance_id DESC;

IF DB_ID('msdb') IS NOT NULL
BEGIN
  PRINT '=== ReplLatencyLog (ostatnie wpisy) ===';
  SELECT TOP 50 * FROM msdb.dbo.ReplLatencyLog ORDER BY id DESC;
END
