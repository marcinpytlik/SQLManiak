/*
  SPRZĄTANIE NA A: usuń dystrybucję po migracji na C.
  Uruchom na **Server A**.
*/
DECLARE @PublisherOnC sysname = N'ServerC';
DECLARE @DistributionDb sysname = N'distribution';

-- Upewnij się, że nie ma aktywnych jobów Agentów replikacji
-- (zatrzymaj/usuń joby jeśli pozostały)
-- EXEC msdb.dbo.sp_delete_job @job_name = N'...';

-- Usuń wpis wydawcy (C) z A jako dystrybutora zdalnego
BEGIN TRY
  EXEC sp_dropdistpublisher @publisher = @PublisherOnC;
END TRY BEGIN CATCH PRINT ERROR_MESSAGE(); END CATCH;

-- Usuń bazę dystrybucji (jeśli nie służy innym publikacjom)
BEGIN TRY
  EXEC sp_dropdistributiondb @database = @DistributionDb;
END TRY BEGIN CATCH PRINT ERROR_MESSAGE(); END CATCH;

-- Usuń dystrybutora
BEGIN TRY
  EXEC sp_dropdistributor @no_checks = 1, @ignore_distributor = 1;
END TRY BEGIN CATCH PRINT ERROR_MESSAGE(); END CATCH;

-- Walidacja
EXEC sp_helpdistributor;
