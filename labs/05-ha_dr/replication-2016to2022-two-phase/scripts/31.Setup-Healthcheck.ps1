param([Parameter(Mandatory)][string]$ParamsPath, [int]$EveryMinutes = 10)
$P = Import-PowerShellDataFile $ParamsPath
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.NewPublisherC -InputFile (Join-Path $PSScriptRoot '..\sql_common\11_latency_healthcheck.sql')

$jobName = "Repl Latency Probe - " + $P.Publication
$tsql = @"
DECLARE @job_id UNIQUEIDENTIFIER;
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'$jobName')
BEGIN
  EXEC msdb.dbo.sp_add_job @job_name = N'$jobName', @enabled = 1, @notify_level_eventlog=2, @owner_login_name = N'sa', @job_id = @job_id OUTPUT;
  EXEC msdb.dbo.sp_add_jobstep @job_id=@job_id, @step_name=N'Probe', @subsystem=N'TSQL',
    @command = N'EXEC msdb.dbo.usp_ReplLatency_Probe @publication = N''$($P.Publication)'';',
    @database_name=N'msdb';
  EXEC msdb.dbo.sp_add_schedule @schedule_name=N'$jobName Schedule', @freq_type=4, @freq_interval=1, @freq_subday_type=4, @freq_subday_interval=$EveryMinutes, @active_start_time=0;
  EXEC msdb.dbo.sp_attach_schedule @job_name=N'$jobName', @schedule_name=N'$jobName Schedule';
  EXEC msdb.dbo.sp_add_jobserver @job_name=N'$jobName';
END
ELSE
BEGIN
  PRINT 'Job już istnieje: $jobName';
END
"@

. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.NewPublisherC -Query $tsql
Write-Host "Healthcheck job skonfigurowany na $($P.NewPublisherC): $jobName (co $EveryMinutes min)"
