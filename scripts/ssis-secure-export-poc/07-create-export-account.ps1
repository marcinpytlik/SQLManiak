[CmdletBinding()]
param(
    [string]$DomainDnsName = 'sqllab.local',
    [string]$SamAccountName = 'poc-ssis-export',
    [string]$DisplayName = 'POC SSIS Export Service Account'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$bootstrap = Join-Path $PSScriptRoot '..\poc-active-directory\Initialize-POCActiveDirectory.ps1'

if (-not (Test-Path $bootstrap)) {
    throw "Bootstrap script not found: $bootstrap"
}

& $bootstrap `
    -DomainDnsName $DomainDnsName `
    -OuName 'POC' `
    -SamAccountName $SamAccountName `
    -DisplayName $DisplayName

Write-Host ''
Write-Host 'Expected account:'
Write-Host "  SQLLAB\$SamAccountName"
Write-Host ''
Write-Host 'Expected delegation state:'
Write-Host '  AccountNotDelegated          = True'
Write-Host '  TrustedForDelegation         = False'
Write-Host '  TrustedToAuthForDelegation   = False'
