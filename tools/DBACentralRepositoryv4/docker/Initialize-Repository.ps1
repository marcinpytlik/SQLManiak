#requires -Version 7.0
<#
.SYNOPSIS
  Installs the SQLManiak v4 schema in the Docker repository instance using SQL authentication.
  Does NOT install anything on production.
#>
[CmdletBinding()]
param(
 [switch]$SkipConnectivityCheck
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$envPath=Join-Path $PSScriptRoot '.env'
if(-not (Test-Path -LiteralPath $envPath)) { throw 'No docker/.env. Run Start-Lab.ps1 first.' }
$values=@{}
foreach($line in (Get-Content -LiteralPath $envPath)) {
 if($line -match '^\s*([A-Z_]+)=(.*)$') { $values[$Matches[1]]=$Matches[2] }
}
if(-not $values['REPO_SA_PASSWORD'] -or -not $values['TARGET_SA_PASSWORD']) {
 throw 'Missing SA passwords in docker/.env.'
}
Import-Module SqlServer -ErrorAction Stop
function Invoke-LabSql {
 param([string]$HostPort,[string]$Password,[string]$Database='master',[string]$InputFile,[string]$Query)
 $p=@{
  ServerInstance=$HostPort;Database=$Database;Username='sa';Password=$Password;
  Encrypt='Optional';TrustServerCertificate=$true;ConnectionTimeout=5;QueryTimeout=120;ErrorAction='Stop'
 }
 if($InputFile) { $p['InputFile']=$InputFile }
 else { $p['Query']=$Query }
 Invoke-Sqlcmd @p
}
if(-not $SkipConnectivityCheck) {
 foreach($s in @(@{name='127.0.0.1,15433';pw=$values['REPO_SA_PASSWORD']},@{name='127.0.0.1,15434';pw=$values['TARGET_SA_PASSWORD']})) {
  $ready=$false
  $lastError=$null
  for($attempt=1; $attempt -le 30; $attempt++) {
   try { [void](Invoke-LabSql -HostPort $s.name -Password $s.pw -Query 'SELECT 1 AS Ready;'); $ready=$true; break }
   catch { $lastError=$_.Exception.Message; Write-Warning "Attempt $attempt on $($s.name): $lastError"; Start-Sleep -Seconds 2 }
  }
  if(-not $ready) { throw "SQL not ready on $($s.name). Last error: $lastError" }
  Write-Host "SQL reachable: $($s.name)"
 }
}
foreach($file in @('00_Bootstrap.sql','01_Inventory_Core.sql','02_Patch_Planner.sql','03_Reports.sql')) {
 $path=Join-Path $root "sql/$file"
 $db=if($file -eq '00_Bootstrap.sql') {'master'} else {'DBACentralRepositoryv4'}
 Write-Host "Installing $file ..."
 [void](Invoke-LabSql -HostPort '127.0.0.1,15433' -Password $values['REPO_SA_PASSWORD'] -Database $db -InputFile $path)
}
$result=Invoke-LabSql -HostPort '127.0.0.1,15433' -Password $values['REPO_SA_PASSWORD'] -Database 'DBACentralRepositoryv4' -Query @'
SELECT DB_NAME() AS DatabaseName, (SELECT COUNT(*) FROM patch.PatchGroup) AS PatchGroups;
'@
$result | Format-Table
$config=Join-Path $root 'config/servers.local.json'
if(-not (Test-Path -LiteralPath $config)) {
 $source=Get-Content -LiteralPath (Join-Path $root 'config/servers.example.json') -Raw
 $source | Set-Content -LiteralPath $config -Encoding utf8NoBOM
 Write-Host 'Created config/servers.local.json; ports align with this Docker LAB.'
}
Write-Host 'Repository schema installed. Test dry-run with docker/Test-Inventory.ps1'
