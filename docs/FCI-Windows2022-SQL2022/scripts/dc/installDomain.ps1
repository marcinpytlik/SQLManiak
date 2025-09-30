<#
.SYNOPSIS
  Tworzy NOWY las AD DS z DNS na lokalnym serwerze (Windows Server 2016/2019/2022).
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9\.-]*\.[A-Za-z]{2,}$')]
  [string]$DomainName,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}$')]
  [string]$IPv4Address,
  [int]$PrefixLength = 24,
  [string]$DefaultGateway,
  [string]$InterfaceAlias,
  [string]$DomainNetbiosName,
  [SecureString]$SafeModeAdminPassword
)
$ErrorActionPreference = 'Stop'
function Write-Info($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok($m){ Write-Host "[ OK ] $m" -ForegroundColor Green }
if (Get-Service -Name NTDS -ErrorAction SilentlyContinue) { Write-Ok "Ten serwer już jest kontrolerem domeny. Przerywam."; return }
if (-not $InterfaceAlias) {
  $nic = Get-NetAdapter | Where-Object {$_.Status -eq 'Up' -and $_.HardwareInterface} | Select-Object -First 1
  if (-not $nic) { throw "Nie znaleziono aktywnego interfejsu. Podaj -InterfaceAlias." }
  $InterfaceAlias = $nic.Name
}
Write-Info "Konfiguruję '$InterfaceAlias' na $IPv4Address/$PrefixLength"
$existing = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
if ($existing) {
  foreach($ip in $existing){ if ($ip.PrefixOrigin -ne 'WellKnown') { Remove-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $ip.IPAddress -Confirm:$false -ErrorAction SilentlyContinue } }
}
New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPv4Address -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway -ErrorAction SilentlyContinue | Out-Null
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses 127.0.0.1
Write-Ok "IP/DNS ustawione."
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | Out-Null
if (-not $SafeModeAdminPassword) { $SafeModeAdminPassword = Read-Host -AsSecureString "Hasło DSRM (Safe Mode)" }
if (-not $DomainNetbiosName) { $DomainNetbiosName = ($DomainName.Split('.')[0]).ToUpperInvariant() }
Import-Module ADDSDeployment
Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $DomainNetbiosName -InstallDNS -SafeModeAdministratorPassword $SafeModeAdminPassword -Force -NoRebootOnCompletion:$false
