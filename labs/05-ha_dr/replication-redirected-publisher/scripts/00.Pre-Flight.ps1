[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ParamsPath = "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\Params.sample.psd1"
)

$P = Import-PowerShellDataFile -Path $ParamsPath
Write-Host "=== Pre-Flight Checks ===" -ForegroundColor Yellow

# 0) sqlcmd available
if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
  throw "Brak sqlcmd.exe w PATH. Zainstaluj klienta SQL/SSMS."
}
Write-Host "[OK] sqlcmd.exe dostępny"

# 1) Shares & paths
$paths = @{
  "BackupShareA" = $P.BackupShareA
  "BackupShareC" = $P.BackupShareC
}
foreach ($k in $paths.Keys) {
  $p = $paths[$k]
  if (-not (Test-Path $p)) { throw "Brak dostępu do $k ($p)" }
  Write-Host "[OK] $k dostępny: $p"
}

# Snapshot dir
if (-not (Test-Path $P.SnapshotDirC)) {
  Write-Warning "SnapshotDirC ($($P.SnapshotDirC)) nie istnieje na tej maszynie; upewnij się, że istnieje na serwerze C."
} else {
  Write-Host "[OK] SnapshotDirC istnieje: $($P.SnapshotDirC)"
}

# 2) Network reachability (TCP 1433 domyślnie)
$servers = @($P.PublisherA, $P.NewPublisherC, $P.SubscriberB) | Select-Object -Unique
foreach ($s in $servers) {
  try {
    $t = Test-NetConnection -ComputerName $s -Port 1433 -WarningAction SilentlyContinue
    if ($t.TcpTestSucceeded) {
      Write-Host "[OK] $s: TCP 1433 osiągalny"
    } else {
      Write-Warning "$s: Port 1433 może być nieosiągalny (named instance? firewall?)."
    }
  } catch {
    Write-Warning "$s: Test-NetConnection nieudany: $_"
  }
}

# 3) Server identity and versions
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.PublisherA -Query "SELECT SERVERPROPERTY('MachineName') AS Host, @@SERVERNAME AS ServerName, @@VERSION AS Version;"
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.NewPublisherC -Query "SELECT SERVERPROPERTY('MachineName') AS Host, @@SERVERNAME AS ServerName, @@VERSION AS Version;"
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.SubscriberB -Query "SELECT SERVERPROPERTY('MachineName') AS Host, @@SERVERNAME AS ServerName, @@VERSION AS Version;"

# 4) Database & publication on A
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.PublisherA -Query @"
IF DB_ID(N'$($P.PublisherDb)') IS NULL RAISERROR('Brak bazy $($P.PublisherDb) na A',16,1);
SELECT name,is_published,is_merge_published FROM sys.databases WHERE name = N'$($P.PublisherDb)';
EXEC sp_helppublication @publication = N'$($P.Publication)';
"@

# 5) allow_initialize_from_backup on A
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.PublisherA -Query @"
SELECT name, allow_initialize_from_backup
FROM syspublications WHERE name = N'$($P.Publication)';
"@

# 6) Jobs on A (Log Reader/Distribution)
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.PublisherA -Query @"
SELECT name, enabled FROM msdb.dbo.sysjobs WHERE name LIKE '%Agent%' ORDER BY name;
"@

# 7) B: subscriber DB exists
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.SubscriberB -Query @"
IF DB_ID(N'$($P.SubscriberDb)') IS NULL
  PRINT 'UWAGA: DB subskrybenta nie istnieje (może pull tworzy ją sam)';
ELSE
  SELECT DB_ID(N'$($P.SubscriberDb)') AS SubscriberDbId;
"@

# 8) Distribution status on A
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.PublisherA -Query "EXEC sp_helpdistributor; EXEC sp_helpdistributiondb;"
Write-Host "=== Pre-Flight zakończony. ===" -ForegroundColor Yellow
