/*
  INWENTARYZACJA REPLIKACJI (uruchom na Server A i zarchiwizuj wynik)
  Uzupełnij parametry w sekcji PARAMETRY.
*/
-- ===================== PARAMETRY =====================
DECLARE @Publisher sysname       = N'ServerA';
DECLARE @PublisherDb sysname     = N'TwojaBaza';
DECLARE @Publication sysname     = N'PubName';
DECLARE @Subscriber sysname      = N'ServerB';
DECLARE @SubscriberDb sysname    = N'TwojaBazaB';
DECLARE @Distributor sysname     = N'ServerA'; -- dystrybutor na A
-- =====================================================

-- Podstawowe info o publikacjach
EXEC sp_helppublication @publication = @Publication;

-- Artykuły
EXEC sp_helparticle @publication = @Publication;

-- Subskrypcje
EXEC sp_helpsubscription @publication = @Publication;

-- Agenty (Log Reader, Snapshot, Distribution)
EXEC msdb.dbo.sp_help_job @job_name = N'Log Reader Agent ' + @Publisher + '-' + @PublisherDb;
EXEC msdb.dbo.sp_help_job @job_name = N'Distribution Agent ' + @Publisher + '-' + @PublisherDb + '-' + @Subscriber + '-' + @SubscriberDb;

-- Ścieżki i ustawienia dystrybucji
EXEC sp_helpdistributiondb;
EXEC sp_helpdistributor;

-- Konta jobów (proxy/owner)
SELECT j.name AS job_name, SUSER_SNAME(j.owner_sid) AS owner_login
FROM msdb.dbo.sysjobs AS j
WHERE j.name LIKE '%Agent%'
ORDER BY j.name;

-- Loginy potrzebne na C (z SID)
SELECT name, sid, type_desc FROM sys.server_principals
WHERE name IN (N'repl_distribution', N'repl_logreader', N'repl_snapshot') OR name LIKE N'repl%'
ORDER BY name;
