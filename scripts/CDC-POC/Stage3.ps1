param(
    [string]$ServerInstance = 'sql64',
    [string]$SqlUser,
    [SecureString]$SqlPassword,
    [switch]$FromBeginning
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$deb = Join-Path $root 'Debezium'
. (Join-Path $root 'POC.Common.ps1')

Assert-DockerDesktop

Write-PocStep 'Checking Debezium status'
& (Join-Path $deb '03_Status.ps1')

Write-PocStep 'Starting Kafka consumer in a separate PowerShell window'
$consumerScript = Join-Path $deb '05_Consume.ps1'
$consumerArgs = @('-NoExit', '-ExecutionPolicy', 'Bypass', '-File', $consumerScript)
if ($FromBeginning) {
    $consumerArgs += '-FromBeginning'
}
Start-Process powershell.exe -ArgumentList $consumerArgs | Out-Null
Start-Sleep -Seconds 2

Write-PocStep 'Executing end-to-end SQL changes'
Invoke-PocSqlFile -ServerInstance $ServerInstance `
    -Path (Join-Path $deb '06_TestChanges.sql') `
    -SqlUser $SqlUser `
    -SqlPassword $SqlPassword

Write-PocPass 'Stage 3 test changes executed. Verify c/u/d events in the consumer window.'
