param(
  [Parameter(Mandatory)][hashtable]$P,
  [ValidateSet('A','C')][string]$On = 'C',
  [int]$Hours = 24
)
$server = if ($On -eq 'C') { $P.NewPublisherC } else { $P.PublisherA }
$query = @"
USE msdb;
SELECT TOP 200
  log_time, publication, subscriber,
  overall_latency_ms,
  publisher_latency_ms, distributor_latency_ms, subscriber_latency_ms,
  status_desc
FROM dbo.ReplLatencyLog
WHERE log_time >= DATEADD(hour, -$Hours, SYSDATETIME())
ORDER BY log_time DESC;
"@
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $server -Query $query -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword
