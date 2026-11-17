#requires -Version 7.2
<#
 Test 34: read-only static permissions inventory for the ACTUAL local DHC v1.5.
 No server changes. This is a heuristic review, not a permissions proof.
#>
[CmdletBinding()]
param(
 [string]$SqlFile=(Join-Path $PSScriptRoot 'SQLManiak_Daily_Health_Check_v1_5_CSV.sql')
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $SqlFile -PathType Leaf)){throw "Missing original local DHC SQL: $SqlFile"}
$sql=Get-Content -LiteralPath $SqlFile -Raw -Encoding utf8
$sha=(Get-FileHash -LiteralPath $SqlFile -Algorithm SHA256).Hash
Write-Host "Test 34 | Original local SQL: $SqlFile"
Write-Host "SHA256: $sha"
$checks=[ordered]@{
 'Server performance DMVs'='(?i)\bsys\.dm_(?:os_|exec_|io_|tran_|db_)'
 'Server services security DMV'='(?i)\bsys\.dm_server_services\b'
 'SQL errorlog reading'='(?i)\b(?:xp_readerrorlog|sp_readerrorlog|sp_enumerrorlogs)\b'
 'SQL Agent msdb objects'='(?i)\b(?:msdb|sysjobs|sysjobhistory|sysjobactivity|sysschedules|sysjobschedules)\b'
 'Backup and database metadata'='(?i)\b(?:backupset|backupmediafamily|sys\.databases|sys\.master_files)\b'
 'Cross-database references'='(?i)\b(?:USE\s+\[?\w+|(?:\[\w+\]|\w+)\.(?:sys|dbo)\.)'
 'Dynamic SQL or EXECUTE'='(?i)\b(?:EXEC(?:UTE)?|sp_executesql)\b'
 'Opt-in history control'='(?im)^\s*DECLARE\s+@SaveHistory\s+bit\s*=\s*[01]\s*;'
 'Potential changes (manual review)'='(?im)\b(?:ALTER|DROP|TRUNCATE|DELETE|UPDATE|INSERT|MERGE|CREATE|DBCC)\b'
}
foreach($item in $checks.GetEnumerator()){
 $count=[regex]::Matches($sql,$item.Value).Count
 [pscustomobject]@{Feature=$item.Key;Matches=$count;Review=if($count){'REVIEW'}else{'NOT_SEEN'}}
}
if(([regex]::Matches($sql,$checks['Opt-in history control'])).Count -ne 1){
 throw 'Expected a single @SaveHistory declaration. Collector may not be compatible.'
}
Write-Warning 'Static scan is not exhaustive. Inspect conditional paths, CATCH alerts, dynamic SQL, and permissions under the actual source login.'
Write-Host 'Proposed LAB baseline (validate, do not assume sufficient): VIEW SERVER PERFORMANCE STATE, VIEW SERVER SECURITY STATE, VIEW ANY ERROR LOG; msdb SQLAgentReaderRole. No sysadmin.' -ForegroundColor Cyan
