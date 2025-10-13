/*
  DLA PUSH: odtwórz agenty dystrybucji na C dla istniejących subskrypcji.
  Uruchom na C (Publisher).
*/
DECLARE @Publication sysname   = N'PubName';
DECLARE @Subscriber sysname    = N'ServerB';
DECLARE @SubscriberDb sysname  = N'TwojaBazaB';

-- Załóżmy, że subskrypcja już istnieje (po ścieżce 1) i nie wymaga reinitu.
-- Dodaj agent push (job na dystrybutorze=C). Użyj odpowiednich parametrów bezpieczeństwa.
EXEC sp_addpushsubscription_agent
  @publication = @Publication,
  @subscriber = @Subscriber,
  @subscriber_db = @SubscriberDb,
  @job_login = NULL,      -- lub konto domenowe/SQL
  @job_password = NULL,
  @subscriber_security_mode = 1,  -- 1 = Windows Auth (dopasuj)
  @frequency_type = 64,    -- start automat.
  @frequency_interval = 1,
  @frequency_relative_interval = 0,
  @frequency_recurrence_factor = 0,
  @frequency_subday = 4,
  @frequency_subday_interval = 5,
  @active_start_time_of_day = 0,
  @active_end_time_of_day = 235959,
  @active_start_date = 0,
  @active_end_date = 0,
  @dts_package_location = N'Distributor';

-- Start jobu (nazwa jest generowana: "Distribution Agent <Publisher>-<DB>-<Subscriber>-<SubscriberDB>")
-- Zweryfikuj dokładną nazwę w msdb i uruchom:
-- EXEC msdb.dbo.sp_start_job @job_name = N'Distribution Agent ServerC-TwojaBaza-ServerB-TwojaBazaB';
