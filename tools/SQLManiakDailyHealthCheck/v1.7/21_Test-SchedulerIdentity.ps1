#requires -Version 7.2
<#
.SYNOPSIS
 Check the actual Windows scheduler identity, access to DHC files and DPAPI.
.DESCRIPTION
 Read-only: no SQL collection, no Agent job changes, no secrets printed.
 Run under exactly the SAME Windows account and on the SAME machine that
 will execute CmdExec job. This is a preflight, not impersonation.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$ConfigPath,
 [ValidateSet('LAB','DEV','TEST','DR','PROD')][string]$Environment='LAB',
 [switch]$CheckSqlPreview
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not $IsWindows){throw 'Windows account test requires Windows.'}
$identity=[System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$hostName=[System.Environment]::MachineName
$ps= $PSVersionTable.PSVersion.ToString()
$issues=[System.Collections.Generic.List[string]]::new()
$path=[IO.Path]::GetFullPath($ConfigPath)
$dir=Split-Path -Parent $path
$runner=Join-Path $PSScriptRoot '17_Invoke-DHC-Scheduled.ps1'
$source=Join-Path $PSScriptRoot 'SQLManiak_Daily_Health_Check_v1_5_CSV.sql'
$config=$null
Write-Host "Identity: $identity"
Write-Host "Machine: $hostName; PowerShell: $ps"
if(-not(Test-Path -LiteralPath $path -PathType Leaf)){$issues.Add('Missing scheduler.json')}
if(-not(Test-Path -LiteralPath $runner -PathType Leaf)){$issues.Add('Missing wrapper script')}
if(-not(Test-Path -LiteralPath $source -PathType Leaf)){$issues.Add('Missing local DHC v1.5 source')}
if($issues.Count -eq 0){
 try{
  $config=Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
  if($config.Version -ne 1 -or [string]::IsNullOrWhiteSpace([string]$config.RepositoryServer)) {
   throw 'Unsupported or incomplete scheduler config.'
  }
  $names=@([string]$config.RepositoryCredentialFile)
  foreach($p in $config.Targets.PSObject.Properties){$names+= [string]$p.Value}
  foreach($n in $names){
   if([string]::IsNullOrWhiteSpace($n) -or [IO.Path]::IsPathRooted($n) -or [IO.Path]::GetFileName($n) -ne $n) {
    throw "Invalid local credential filename."
   }
   $pathToSecret=Join-Path $dir $n
   $secret=Import-Clixml -LiteralPath $pathToSecret
   if($secret -isnot [PSCredential]) {throw 'DPAPI import did not return PSCredential.'}
  }
  Write-Host "DPAPI: PASS ($($names.Count) credential files loaded, passwords not displayed)." -ForegroundColor Green
 }catch{$issues.Add("DPAPI/config: $($_.Exception.Message)")}
}
if($issues.Count -eq 0 -and $CheckSqlPreview){
 try {
  & $runner -ConfigPath $ConfigPath -Environment $Environment
  Write-Host 'Repository preview: PASS' -ForegroundColor Green
 }catch{$issues.Add("SQL preview: $($_.Exception.Message)")}
}
if($issues.Count -gt 0){
 foreach($issue in $issues){Write-Warning $issue}
 throw "Scheduler identity preflight: FAILED ($($issues.Count) checks)."
}
[pscustomobject]@{
 Identity=$identity
 Machine=$hostName
 PowerShell=$ps
 DPAPI='PASS'
 SqlPreview=if($CheckSqlPreview){'PASS'}else{'NOT_RUN'}
 TestResult='PASS'
}
