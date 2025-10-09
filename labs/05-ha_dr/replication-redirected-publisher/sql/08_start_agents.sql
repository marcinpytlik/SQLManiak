/*
  Uruchom ponownie agenty replikacji po przełączeniu.
  Uwaga: w zależności od topologii jobs mogą żyć na A (dystrybutor) lub C.
  Poniżej wariant uruchamiany na A (dystrybutor), dopasuj nazwy.
*/
DECLARE @Publisher sysname    = N'ServerA';      -- oryginalna nazwa w jobach; jeśli tworzysz nowe na C, zmień
DECLARE @Db sysname           = N'TwojaBaza';
DECLARE @Subscriber sysname   = N'ServerB';
DECLARE @SubscriberDb sysname = N'TwojaBazaB';

EXEC msdb.dbo.sp_start_job @job_name = N'Log Reader Agent ' + @Publisher + N'-' + @Db;
EXEC msdb.dbo.sp_start_job @job_name = N'Distribution Agent ' + @Publisher + N'-' + @Db + N'-' + @Subscriber + N'-' + @SubscriberDb;
