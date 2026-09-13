#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SharePath = '\\dc01.sqllab.local\SSISLab$',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$UserName = 'SQLLAB\poc-ssis-export'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "Orchestrator : $env:COMPUTERNAME"
Write-Host "SharePath    : $SharePath"
Write-Host "UserName     : $UserName"

$cred = Get-Credential $UserName
$driveName = 'POC'

try {
    if (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue) {
        Remove-PSDrive $driveName -Force
    }

    New-PSDrive `
        -Name $driveName `
        -PSProvider FileSystem `
        -Root $SharePath `
        -Credential $cred `
        -ErrorAction Stop | Out-Null

    Write-Host ''
    Write-Host '=== Stage 5 output files ==='
    Get-ChildItem 'POC:' -ErrorAction Stop |
        Sort-Object LastWriteTime -Descending |
        Select-Object Name, Length, LastWriteTime

    Write-Host ''
    Write-Host 'Share access succeeded as SQLLAB\poc-ssis-export.'
}
finally {
    if (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue) {
        Remove-PSDrive $driveName -Force
        Write-Host 'Removed PSDrive POC.'
    }
}
