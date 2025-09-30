<#
.SYNOPSIS
  Tworzy klaster WSFC, ustawia FSW i dodaje dostępne dyski.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [string]$ClusterName = 'SQLLAB',
  [Parameter(Mandatory=$true)][string]$ClusterIP,
  [Parameter(Mandatory=$true)][string]$WitnessPath,
  [string[]]$Nodes = @('NODE1','NODE2')
)
$ErrorActionPreference='Stop'
Install-WindowsFeature Failover-Clustering, RSAT-Clustering-PowerShell -IncludeManagementTools | Out-Null
New-Cluster -Name $ClusterName -Node $Nodes -StaticAddress $ClusterIP -NoStorage | Out-Null
Set-ClusterQuorum -Cluster $ClusterName -FileShareWitness $WitnessPath | Out-Null
Get-ClusterAvailableDisk | Add-ClusterDisk | Out-Null
Write-Host "WSFC '$ClusterName' utworzony. Quorum: $WitnessPath" -ForegroundColor Green
