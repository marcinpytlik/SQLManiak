#requires -Version 7.0
<#
.SYNOPSIS
 Docker LAB only: verify MODIFIED (ALTER COLUMN) and REMOVED (DROP TABLE)
 in inventory.ChangeEvent.
.DESCRIPTION
 The test creates its own probe table in tempdb, so no existing user objects are
 touched. It performs baseline, ALTER and DROP scans and checks expected events.
 Never run this against production.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$envFile=Join-Path $PSScriptRoot '.env'
if(-not (Test-Path -LiteralPath $envFile)) { throw 'Missing docker/.env. Run Start-Lab.ps1 first.' }
$values=@{}
foreach($line in (Get-Content -LiteralPath $envFile)) {
 if($line -match '^\s*([A-Z_]+)=(.*)$') { $values[$Matches[1]]=$Matches[2] }
}
if(-not $values['REPO_SA_PASSWORD'] -or -not $values['TARGET_SA_PASSWORD']) {
 throw 'LAB SA passwords missing from docker/.env.'
}
$configFile=Join-Path $root 'config/servers.local.json'
if(-not (Test-Path -LiteralPath $configFile)) { throw 'Missing config/servers.local.json.' }
$cfg=Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
if($cfg.repository.server -ne '127.0.0.1,15433' -or
   $cfg.repository.database -ne 'DBACentralRepositoryv4' -or
   @($cfg.sourceServers).Count -ne 1 -or
   $cfg.sourceServers[0].name -ne '127.0.0.1,15434' -or
   $cfg.sourceServers[0].environment -ne 'LAB') {
 throw 'SAFETY STOP: this script is restricted to the local Docker LAB.'
}
Import-Module SqlServer -ErrorAction Stop
function Invoke-LabSql {
 param([string]$Server,[string]$Password,[string]$Database,[string]$Query)
 Invoke-Sqlcmd -ServerInstance $Server -Database $Database -Username 'sa' -Password $Password `
  -Encrypt Optional -TrustServerCertificate -ConnectionTimeout 5 -QueryTimeout 120 `
  -Query $Query -ErrorAction Stop
}
function Get-LastScan {
 $scan=Invoke-LabSql -Server '127.0.0.1,15433' -Password $values['REPO_SA_PASSWORD'] -Database 'DBACentralRepositoryv4' -Query @'
SELECT TOP (1) sr.ScanRunId,sr.ScanStatus
FROM inventory.ScanRun AS sr
JOIN inventory.Instance AS i ON i.InstanceId=sr.InstanceId
WHERE i.ServerInstance=N'127.0.0.1,15434'
ORDER BY sr.ScanRunId DESC;
'@
 if($null -eq $scan -or $scan.ScanStatus -ne 'COMPLETE') {
  throw 'Collector did not produce a COMPLETE ScanRun for target.'
 }
 return [long]$scan.ScanRunId
}
function Run-Inventory {
 & (Join-Path $PSScriptRoot 'Test-Inventory.ps1') -Persist
 return (Get-LastScan)
}
function Get-EventCount {
 param([long]$ScanRunId,[string]$Category,[string]$ChangeType,[string]$TableName,[string]$ColumnName='')
 # TableName and ColumnName are trusted generated identifiers, not user input.
 $needle="'%$TableName%'"
 $columnPredicate=if($ColumnName){" AND JSON_VALUE(COALESCE(NewJson,OldJson),'$.ColumnName')=N'$ColumnName'"}else{''}
 $jsonColumn=if($ChangeType -eq 'REMOVED'){'OldJson'}else{'NewJson'}
 $query=@"
SELECT COUNT_BIG(*) AS EventCount
FROM inventory.ChangeEvent
WHERE ScanRunId=$ScanRunId AND Category='$Category' AND ChangeType='$ChangeType'
 AND $jsonColumn LIKE $needle
 $columnPredicate;
"@
 $result=Invoke-LabSql -Server '127.0.0.1,15433' -Password $values['REPO_SA_PASSWORD'] -Database 'DBACentralRepositoryv4' -Query $query
 return [long]$result.EventCount
}

$tableName='InventoryV4Probe_'+(Get-Date -Format 'yyyyMMddHHmmssfff')
# Identity verification before any DDL. These are deliberately fixed LAB-only endpoints.
$identity=Invoke-LabSql -Server '127.0.0.1,15434' -Password $values['TARGET_SA_PASSWORD'] -Database 'master' -Query "SELECT @@SERVERNAME AS ServerName, DB_NAME() AS DatabaseName;"
if($identity.ServerName -ne 'sqlmaniak-v4-target') {
 throw "SAFETY STOP: connected target is $($identity.ServerName), not sqlmaniak-v4-target."
}
Write-Host "LAB fixture: tempdb.dbo.$tableName"
$create="CREATE TABLE dbo.[$tableName] ([Id] int NOT NULL CONSTRAINT [PK_$tableName] PRIMARY KEY, [Note] nvarchar(50) NULL);"
[void](Invoke-LabSql -Server '127.0.0.1,15434' -Password $values['TARGET_SA_PASSWORD'] -Database 'tempdb' -Query $create)
try {
 Write-Host 'Baseline: collect fresh snapshot containing the fixture...'
 $baseline=Run-Inventory
 Write-Host "  Baseline ScanRunId=$baseline"

 Write-Host 'MODIFIED: ALTER COLUMN Note nvarchar(50) -> nvarchar(100)...'
 $alter="ALTER TABLE dbo.[$tableName] ALTER COLUMN [Note] nvarchar(100) NULL;"
 [void](Invoke-LabSql -Server '127.0.0.1,15434' -Password $values['TARGET_SA_PASSWORD'] -Database 'tempdb' -Query $alter)
 $modifiedScan=Run-Inventory
 $modified=Get-EventCount -ScanRunId $modifiedScan -Category 'COLUMN' -ChangeType 'MODIFIED' -TableName $tableName -ColumnName 'Note'
 if($modified -lt 1) { throw "FAIL MODIFIED: COLUMN Note not found in ChangeEvent, ScanRunId=$modifiedScan" }
 Write-Host "PASS MODIFIED: COLUMN Note, ScanRunId=$modifiedScan, events=$modified"

 Write-Host 'REMOVED: DROP the same LAB-only fixture table...'
 $drop="DROP TABLE dbo.[$tableName];"
 [void](Invoke-LabSql -Server '127.0.0.1,15434' -Password $values['TARGET_SA_PASSWORD'] -Database 'tempdb' -Query $drop)
 $removedScan=Run-Inventory
 $removedObject=Get-EventCount -ScanRunId $removedScan -Category 'OBJECT' -ChangeType 'REMOVED' -TableName $tableName
 $removedColumn=Get-EventCount -ScanRunId $removedScan -Category 'COLUMN' -ChangeType 'REMOVED' -TableName $tableName
 if($removedObject -lt 1 -or $removedColumn -lt 2) {
  throw "FAIL REMOVED: OBJECT=$removedObject COLUMN=$removedColumn in ScanRunId=$removedScan"
 }
 Write-Host "PASS REMOVED: OBJECT=$removedObject COLUMN=$removedColumn, ScanRunId=$removedScan"
 Write-Host 'PASS: MODIFIED + REMOVED verified in DBACentralRepositoryv4.'
}
finally {
 # Cleanup only fixture table if a test aborts before DROP.
 $cleanup=@"
IF OBJECT_ID(N'dbo.$tableName',N'U') IS NOT NULL DROP TABLE dbo.[$tableName];
"@
 try {
  [void](Invoke-LabSql -Server '127.0.0.1,15434' -Password $values['TARGET_SA_PASSWORD'] -Database 'tempdb' -Query $cleanup)
 } catch { Write-Warning "Fixture cleanup failed: $($_.Exception.Message)" }
}
