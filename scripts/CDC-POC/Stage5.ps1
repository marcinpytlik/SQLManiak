param(
    [string]$ServerInstance = 'sql64',
    [string]$SqlUser,
    [SecureString]$SqlPassword
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
. (Join-Path $root 'POC.Common.ps1')

Write-PocStep 'Stage 5 - Production Readiness baseline checks'

$ops = Join-Path (Join-Path $root 'Tests') '09_OperationalChecks.sql'
Invoke-PocSqlFile -ServerInstance $ServerInstance -Path $ops -SqlUser $SqlUser -SqlPassword $SqlPassword

Write-PocStep 'Production Readiness checklist'
$checklist = Join-Path (Join-Path $root 'Stages') 'Stage-05-Production-Readiness.md'
Write-Host "Review and complete: $checklist"
Start-Process $checklist

Write-PocPass 'Stage 5 baseline checks executed. Final GO/NO-GO requires completion of the checklist and review of Stage 4 results.'
