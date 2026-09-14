param(
    [string]$ServerInstance = 'sql64',
    [string]$SqlUser,
    [SecureString]$SqlPassword,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$deb = Join-Path $root 'Debezium'
. (Join-Path $root 'POC.Common.ps1')

if (-not $Force) {
    Write-PocWarn 'This cleanup removes the Debezium/Kafka lab stack and drops CDC_Lab.'
    $answer = Read-Host 'Type CLEANUP to continue'
    if ($answer -ne 'CLEANUP') {
        Write-Host 'Cancelled.'
        exit 0
    }
}

Write-PocStep 'Stopping and removing Debezium/Kafka lab stack'
if (Get-Command docker -ErrorAction SilentlyContinue) {
    & (Join-Path $deb '99_StopAndCleanup.ps1')
}
else {
    Write-PocWarn 'docker not found - skipping Docker cleanup.'
}

Write-PocStep 'Removing SQL Server CDC lab'
Invoke-PocSqlFile -ServerInstance $ServerInstance `
    -Path (Join-Path $root '99_Cleanup.sql') `
    -SqlUser $SqlUser `
    -SqlPassword $SqlPassword

Write-PocStep 'Verification'
Invoke-PocQuery -ServerInstance $ServerInstance `
    -Query "SELECT DB_ID(N'CDC_Lab') AS CDC_Lab_DatabaseId;" `
    -SqlUser $SqlUser `
    -SqlPassword $SqlPassword

Write-PocPass 'Cleanup completed.'
