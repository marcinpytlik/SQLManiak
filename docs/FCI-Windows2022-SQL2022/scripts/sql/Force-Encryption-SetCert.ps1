<#
.SYNOPSIS
  Ustawia wymuszenie szyfrowania (ForceEncryption=1) i przypisuje certyfikat do instancji SQL (MSSQLSERVER).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Thumbprint,
  [string]$InstanceRegPath = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\SuperSocketNetLib'
)
$ErrorActionPreference='Stop'
$thumb = ($Thumbprint -replace '\s','').ToUpperInvariant()
Set-ItemProperty -Path $InstanceRegPath -Name "Certificate" -Value $thumb
Set-ItemProperty -Path $InstanceRegPath -Name "ForceEncryption" -Value 1 -Type DWord
Write-Host "Ustawiono certyfikat ($thumb) i ForceEncryption=1." -ForegroundColor Green
Write-Host "Zrestartuj zasób SQL w klastrze, aby zastosować: Stop-ClusterResource 'SQL Server (MSSQLSERVER)'; Start-ClusterResource 'SQL Server (MSSQLSERVER)'" -ForegroundColor Yellow
