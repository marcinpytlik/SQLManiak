/*
  Mini‑dashboard DMV dla replikacji (Publisher/Distributor view)
  Uruchamiaj tam, gdzie masz dostęp do dystrybucji i msdb.
*/

-- ========== PARAMETRY ==========
DECLARE @Publication sysname   = N'PubName';
DECLARE @Publisher sysname     = N'ServerC';      -- aktualny publisher
DECLARE @PublisherDb sysname   = N'TwojaBaza';
DECLARE @Subscriber sysname    = N'ServerB';
DECLARE @SubscriberDb sysname  = N'TwojaBazaB';
-- ================================

PRINT '=== Status publikacji ===';
EXEC sp_helppublication @publication = @Publication;

PRINT '=== Undistributed Commands (liczba) ===';
EXEC sp_replmonitorsubscriptionpendingcmds
  @publisher = @Publisher, @publisher_db = @PublisherDb,
  @publication = @Publication, @subscriber = @Subscriber,
  @destination_db = @SubscriberDb;

PRINT '=== Token tracer: utwórz i sprawdź historię (latency end-to-end) ===';
EXEC sp_posttracertoken @publication = @Publication;
EXEC sp_helptracertokenhistory @publication = @Publication;

PRINT '=== Ostatnie błędy jobów replikacji (msdb) ===';
SELECT TOP 50 j.name AS job_name, h.run_date, h.run_time, h.step_name, h.message
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
WHERE j.name LIKE '%Agent%' AND h.run_status <> 1
ORDER BY h.instance_id DESC;

PRINT '=== Ostatnie wykonania jobów replikacji ===';
SELECT TOP 50 j.name AS job_name, h.run_date, h.run_time, h.run_duration, h.step_name, h.message
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
WHERE j.name LIKE '%Agent%' AND h.step_id = 0  -- wpisy ogólne jobu
ORDER BY h.instance_id DESC;

PRINT '=== sp_replcounters (skrót liczników) ===';
EXEC sp_replcounters;

PRINT '=== Baza jest publikowana? ===';
SELECT name, is_published, is_distributor, is_merge_published
FROM sys.databases WHERE name = @PublisherDb;

-- Jeżeli masz dostęp do bazy distribution (lokalnie):
IF DB_ID('distribution') IS NOT NULL
BEGIN
  PRINT '=== distribution: ostatnie 100 błędów agentów (msrepl_errors) ===';
  SELECT TOP 100 time, agent_id, error_code, error_text
  FROM distribution.dbo.msrepl_errors
  ORDER BY time DESC;

  PRINT '=== distribution: status agentów dystrybucji (msdistribution_agents) ===';
  SELECT TOP 100 name, subscriber_db, subscriber_name, publication, anonymous_subid, profile_id
  FROM distribution.dbo.msdistribution_agents
  ORDER BY name;
END
