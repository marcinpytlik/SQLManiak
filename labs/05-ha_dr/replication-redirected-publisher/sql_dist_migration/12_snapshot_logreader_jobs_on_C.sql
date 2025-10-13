/*
  Na C: zapewnij Snapshot Agent job dla publikacji oraz działający Log Reader.
  Jeśli publikacje przetrwały KEEP_REPLICATION, mogło nie istnieć lokalne joby.
*/
DECLARE @Publication sysname = N'PubName';

-- Utwórz/odśwież Snapshot Agent job (tworzy go sp_addpublication_snapshot)
EXEC sp_addpublication_snapshot @publication = @Publication;

-- (Opcjonalnie) Dostosuj konto bezpieczeństwa agentów, jeżeli nie domyślne:
-- EXEC sp_change_logreader_agent @job_login = N'DOMENA\konto', @job_password = N'***';

-- Walidacja jobów
SELECT j.name, SUSER_SNAME(j.owner_sid) AS owner_login
FROM msdb.dbo.sysjobs AS j
WHERE j.name LIKE N'%Agent%'
ORDER BY j.name;
