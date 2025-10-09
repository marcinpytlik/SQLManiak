param(
  [Parameter(Mandatory)][hashtable]$P,
  [ValidateSet('A','C')][string]$On = 'C',
  [int]$EveryMinutes = 10
)
# Tworzy job SQL Agent, który co X minut uruchamia usp_ReplLatency_Probe w msdb.
$server = if ($On -eq 'C') { $P.NewPublisherC } else { $P.PublisherA }

$stepTsql = @"
EXEC msdb.dbo.usp_ReplLatency_Probe
  @Publication = N'$($P.Publication)',
  @Publisher   = N'$($On -eq 'C' ? $P.NewPublisherC : $P.PublisherA)',
  @PublisherDb = N'$($P.PublisherDb)',
  @Subscriber  = N'$($P.SubscriberB)',
  @SubscriberDb= N'$($P.SubscriberDb)';
"@

# Upewnij się, że obiekty msdb istnieją
. "$PSScriptRoot\Resolve-RepoPath.ps1" -RelativePath 'sql\12_latency_healthcheck.sql' | Tee-Object -Variable createSql | Out-Null
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $server -InputFile $createSql -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword

# Utwórz job
$jobName = "Repl Latency Probe - " + $P.Publication
$tsqlCreateJob = @"
DECLARE @job_id UNIQUEIDENTIFIER;
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'$jobName')
BEGIN
  EXEC msdb.dbo.sp_add_job @job_name = N'$jobName', @enabled = 1, @notify_level_eventlog = 2, @owner_login_name = N'sa', @job_id = @job_id OUTPUT;
  EXEC msdb.dbo.sp_add_jobstep @job_id = @job_id, @step_name = N'Probe', @subsystem = N'TSQL', @command = N'$($stepTsql.Replace('''',''''''))', @database_name = N'msdb';
  EXEC msdb.dbo.sp_add_schedule @schedule_name = N'$jobName Schedule', @freq_type = 4, @freq_interval = 1, @freq_subday_type = 4, @freq_subday_interval = $EveryMinutes, @active_start_time = 0;
  EXEC msdb.dbo.sp_attach_schedule @job_name = N'$jobName', @schedule_name = N'$jobName Schedule';
  EXEC msdb.dbo.sp_add_jobserver  @job_name = N'$jobName';
END
ELSE
BEGIN
  PRINT 'Job już istnieje: $jobName';
END
"@

. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $server -Query $tsqlCreateJob -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword

Write-Host "Healthcheck job skonfigurowany na $server: $jobName (co $EveryMinutes min)"
