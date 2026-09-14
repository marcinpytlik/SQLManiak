param(
    [string]$ServerInstance = 'sql64',
    [string]$SqlHost = '192.168.50.24',
    [string]$SqlUser,
    [SecureString]$SqlPassword,
    [SecureString]$DebeziumPassword
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$deb = Join-Path $root 'Debezium'
. (Join-Path $root 'POC.Common.ps1')

Assert-DockerDesktop

if ($null -eq $DebeziumPassword) {
    $DebeziumPassword = Read-Host 'Password for SQL login debezium' -AsSecureString
}

$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($DebeziumPassword)
try {
    $plainDebeziumPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
}

try {
    Write-PocStep 'Preparing Debezium SQL login'
    Invoke-PocSqlFile -ServerInstance $ServerInstance `
        -Path (Join-Path $deb '00_CreateDebeziumLogin.sql') `
        -SqlUser $SqlUser `
        -SqlPassword $SqlPassword `
        -Variables @{ DebeziumPassword = $plainDebeziumPassword }

    Write-PocStep 'Starting Kafka and Debezium Connect'
    & (Join-Path $deb '01_Start.ps1')

    $env:DEBEZIUM_SQL_PASSWORD = $plainDebeziumPassword
    $env:DEBEZIUM_SQL_HOST = $SqlHost

    Write-PocStep "Registering connector against $SqlHost"
    & (Join-Path $deb '02_RegisterConnector.ps1')

    Write-PocStep 'Connector status'
    & (Join-Path $deb '03_Status.ps1')

    Write-PocStep 'Kafka topics'
    & (Join-Path $deb '04_ListTopics.ps1')

    Write-PocPass 'Stage 2 completed. Connector and task should both be RUNNING.'
}
finally {
    Remove-Item Env:DEBEZIUM_SQL_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:DEBEZIUM_SQL_HOST -ErrorAction SilentlyContinue
    $plainDebeziumPassword = $null
}
