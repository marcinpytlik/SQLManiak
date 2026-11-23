#requires -Version 7.0
<#
.SYNOPSIS
  Creates credentials for a local Docker LAB and launches two SQL Server 2022 containers.
  Never runs on a production server.
#>
[CmdletBinding()]
param([switch]$ForceRecreate)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$labPath=$PSScriptRoot
$root=Split-Path $labPath -Parent
$envPath=Join-Path $labPath '.env'
$compose=Join-Path $labPath 'docker-compose.yml'

if(-not (Get-Command docker -ErrorAction SilentlyContinue)) {
 throw 'Docker CLI not found. Install/start Docker Desktop with Linux containers.'
}
& docker info --format '{{.ServerVersion}}' | Out-Null
if($LASTEXITCODE -ne 0) { throw 'Docker engine not available. Start Docker Desktop.' }
if(-not (Test-Path -LiteralPath $envPath)) {
 function New-LabPassword {
  $bytes=[byte[]]::new(24)
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  return ('A1!' + [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','X').Replace('/','Y'))
 }
 $r=New-LabPassword
 $t=New-LabPassword
 @("REPO_SA_PASSWORD=$r","TARGET_SA_PASSWORD=$t") |
   Set-Content -LiteralPath $envPath -Encoding utf8NoBOM
 Write-Host 'Generated docker/.env with separate strong SA passwords (not printed).'
}
$upArgs=@('compose','--env-file',$envPath,'-f',$compose,'up','-d')
if($ForceRecreate) { $upArgs+= '--force-recreate' }
& docker @upArgs
if($LASTEXITCODE -ne 0) { throw 'Docker compose up failed.' }
& docker compose --env-file $envPath -f $compose ps
if($LASTEXITCODE -ne 0) { throw 'Docker compose ps failed.' }
Write-Host 'LAB SQL endpoints: localhost,15433 (repository); localhost,15434 (target).'
Write-Host 'Next: pwsh ./docker/Initialize-Repository.ps1'
