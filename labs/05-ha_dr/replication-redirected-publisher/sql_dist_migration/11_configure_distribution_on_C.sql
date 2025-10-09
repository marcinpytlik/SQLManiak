/*
  KONFIGURACJA DYSTRYBUCJI NA C (lokalny dystrybutor).
  Uruchom na **Server C** z uprawnieniami sysadmin.
*/
DECLARE @Distributor sysname = N'ServerC';
DECLARE @DistributionDb sysname = N'distribution';
DECLARE @WorkingDir nvarchar(260) = N'D:\ReplShare';  -- katalog snapshotu (udostępnij jeśli push zdalny)
DECLARE @Password nvarchar(128) = N'ZmienToHasloDystrybutora';

-- 1) Skonfiguruj dystrybutora
EXEC sp_adddistributor @distributor = @Distributor, @password = @Password;

-- 2) Baza dystrybucji
EXEC sp_adddistributiondb
  @database = @DistributionDb,
  @log_file_size = 2;  -- dopasuj do potrzeb

-- 3) Ustawienia globalne (katalog snapshot)
EXEC sp_adddistpublisher
  @publisher = @Distributor,
  @distribution_db = @DistributionDb,
  @security_mode = 1,
  @working_directory = @WorkingDir,
  @trusted = N'false';

-- Walidacja
EXEC sp_helpdistributor;
EXEC sp_helpdistributiondb;
EXEC sp_helpdistpublisher;
