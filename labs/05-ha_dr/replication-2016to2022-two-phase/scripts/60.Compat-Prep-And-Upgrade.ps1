[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ParamsPath,
  [Parameter(Mandatory)][ValidateSet('C','D')][string]$ServerRole,  # C=Publisher, D=Subscriber
  [string[]]$Databases = @('TwojaBaza')
)

$P = Import-PowerShellDataFile $ParamsPath
. "$PSScriptRoot\Invoke-Tsql.ps1"

$server = if ($ServerRole -eq 'C') { $P.NewPublisherC } else { $P.NewSubscriberD }

# Paths
$prep = Join-Path $PSScriptRoot '..\sql_common\20_prep_after_restore.sql'
$flip = Join-Path $PSScriptRoot '..\sql_common\21_upgrade_to_160.sql'

foreach ($db in $Databases) {
  Write-Host ">>> [$server] PREP on $db" -ForegroundColor Cyan
  (Get-Content $prep) -replace "N'TwojaBaza'", ("N'" + $db + "'") | Set-Content "$env:TEMP\prep_$db.sql"
  . "$PSScriptRoot\Invoke-Tsql.ps1" -Server $server -InputFile "$env:TEMP\prep_$db.sql"

  Write-Host ">>> [$server] UPGRADE to 160 on $db" -ForegroundColor Cyan
  (Get-Content $flip) -replace "N'TwojaBaza'", ("N'" + $db + "'") | Set-Content "$env:TEMP\flip_$db.sql"
  . "$PSScriptRoot\Invoke-Tsql.ps1" -Server $server -InputFile "$env:TEMP\flip_$db.sql"
}

Write-Host "Zakończono podniesienie compatibility level na $server." -ForegroundColor Green
