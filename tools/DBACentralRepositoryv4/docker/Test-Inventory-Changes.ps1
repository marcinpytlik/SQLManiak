#requires -Version 7.0
<#
.SYNOPSIS
 Runs two complete Inventory scans in Docker LAB, creates a permanent
 table in tempdb between them and checks that v4 records ADDED.
 tempdb is reset by SQL Server restart; never run against production.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$envFile=Join-Path $PSScriptRoot '.env'
if(-not (Test-Path $envFile)) { throw 'Missing docker/.env' }
$values=@{}
foreach($line in (Get-Content $envFile)) {
 if($line -match '^\s*([A-Z_]+)=(.*)$') { $values[$Matches[1]]=$Matches[2] }
}
if(-not $values['REPO_SA_PASSWORD'] -or -not $values['TARGET_SA_PASSWORD']) {
 throw 'Missing LAB SA credentials'
}
$configFile=Join-Path $root 'config/servers.local.json'
$cfg=Get-Content $configFile -Raw | ConvertFrom-Json
if($cfg.repository.server -ne '127.0.0.1,15433' -or $cfg.sourceServers.Count -ne 1 -or $cfg.sourceServers[0].name -ne '127.0.0.1,15434') {
 throw 'This fixture test is restricted to the local Docker LAB on ports 15433/15434.'
}
Import-Module SqlServer -ErrorAction Stop
function Invoke-LabQuery {
 param([string]$Server,[string]$Password,[string]$Database='master',[string]$Query)
 Invoke-Sqlcmd -ServerInstance $Server -Database $Database -Username sa -Password $Password `
  -Encrypt Optional -TrustServerCertificate -ConnectionTimeout 5 -QueryTimeout 120 `
  -Query $Query -ErrorAction Stop
}
function Invoke-CompleteScan {
 & (Join-Path $PSScriptRoot 'Test-Inventory.ps1') -Persist
 $check=Invoke-LabQuery '127.0.0.1,15433' $values['REPO_SA_PASSWORD'] 'DBACentralRepositoryv4' @'
SELECT TOP(1) ScanRunId,ScanStatus FROM inventory.ScanRun ORDER BY ScanRunId DESC;
'@
 if($null -eq $check -or $check.ScanStatus -ne 'COMPLETE') { throw 'Inventory scan was not COMPLETE.' }
 return [long]$check.ScanRunId
}
Write-Host 'Running initial full scan ...'
$before=Invoke-CompleteScan
Write-Host "Baseline ScanRunId=$before"
$tableName='InventoryProbe_'+(Get-Date -Format 'yyyyMMddHHmmssfff')
$query='CREATE TABLE dbo.'+'['+$tableName+']'+' ([Id] int NOT NULL PRIMARY KEY, [Note] nvarchar(50) NULL);'
[void](Invoke-LabQuery '127.0.0.1,15434' $values['TARGET_SA_PASSWORD'] 'tempdb' $query)
Write-Host "Created LAB table: tempdb.dbo.$tableName"
Write-Host 'Running second full scan ...'
$after=Invoke-CompleteScan
Write-Host "Second ScanRunId=$after"
$result=Invoke-LabQuery '127.0.0.1,15433' $values['REPO_SA_PASSWORD'] 'DBACentralRepositoryv4' @"
SELECT Category,ChangeType,COUNT(*) AS ChangeCount
FROM inventory.ChangeEvent
WHERE ScanRunId=$after
GROUP BY Category,ChangeType ORDER BY Category,ChangeType;
"@
$result | Format-Table -AutoSize
$changed=Invoke-LabQuery '127.0.0.1,15433' $values['REPO_SA_PASSWORD'] 'DBACentralRepositoryv4' @"
SELECT COUNT_BIG(*) AS Cnt FROM inventory.ChangeEvent
WHERE ScanRunId=$after AND Category='OBJECT' AND ChangeType='ADDED'
 AND NewJson LIKE '%$tableName%';
"@
if([long]$changed.Cnt -lt 1) { throw "FAIL: added table $tableName was not detected" }
Write-Host "PASS: schema change captured in ScanRunId=$after"
