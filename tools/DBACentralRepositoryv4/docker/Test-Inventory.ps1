#requires -Version 7.0
<#
.SYNOPSIS
  Runs the initial inventory collector against the Docker target.
  No SQL writes unless -Persist is supplied.
#>
[CmdletBinding()]
param([switch]$Persist)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$envPath=Join-Path $PSScriptRoot '.env'
if(-not (Test-Path $envPath)) { throw 'Run docker/Start-Lab.ps1 first.' }
$values=@{}
foreach($line in (Get-Content $envPath)) {
 if($line -match '^\s*([A-Z_]+)=(.*)$') { $values[$Matches[1]]=$Matches[2] }
}
if(-not $values['TARGET_SA_PASSWORD'] -or -not $values['REPO_SA_PASSWORD']) {
 throw 'Missing SA passwords.'
}
$config=Join-Path $root 'config/servers.local.json'
if(-not (Test-Path $config)) { throw 'Run docker/Initialize-Repository.ps1 first.' }
$src=New-Object System.Management.Automation.PSCredential(
 'sa',(ConvertTo-SecureString $values['TARGET_SA_PASSWORD'] -AsPlainText -Force))
$repo=New-Object System.Management.Automation.PSCredential(
 'sa',(ConvertTo-SecureString $values['REPO_SA_PASSWORD'] -AsPlainText -Force))
$p=@{
 ConfigPath=$config
 SourceCredential=$src
 RepositoryCredential=$repo
}
if($Persist) { $p['Persist']=$true }
& (Join-Path $root 'modules/inventory/Collect-DBAInventory.ps1') @p
