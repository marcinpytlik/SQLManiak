<#
.SYNOPSIS
  Tworzy iSCSI Target z dwoma LUN-ami dla FCI (DATA/LOG) na serwerze STORAGE.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [string]$TargetName = 'SQL-FCI',
  [string]$Path = 'E:\iSCSI',
  [int]$DataSizeGB = 100,
  [int]$LogSizeGB = 60,
  [Parameter(Mandatory=$true)][string]$Node1IP,
  [Parameter(Mandatory=$true)][string]$Node2IP
)
$ErrorActionPreference='Stop'
Install-WindowsFeature FS-iSCSITarget-Server -IncludeManagementTools | Out-Null
New-Item -ItemType Directory -Path $Path -Force | Out-Null
$data = Join-Path $Path 'SQLData-iscsi.vhdx'
$log  = Join-Path $Path 'SQLLogs-iscsi.vhdx'
if (-not (Test-Path $data)) { New-IscsiVirtualDisk -Path $data -SizeBytes ($DataSizeGB*1GB) | Out-Null }
if (-not (Test-Path $log))  { New-IscsiVirtualDisk -Path $log  -SizeBytes ($LogSizeGB*1GB)  | Out-Null }
if (-not (Get-IscsiServerTarget -TargetName $TargetName -ErrorAction SilentlyContinue)) {
  New-IscsiServerTarget -TargetName $TargetName -InitiatorIds "IPAddress:$Node1IP","IPAddress:$Node2IP" | Out-Null
}
Add-IscsiVirtualDiskTargetMapping -TargetName $TargetName -Path $data -ErrorAction SilentlyContinue | Out-Null
Add-IscsiVirtualDiskTargetMapping -TargetName $TargetName -Path $log  -ErrorAction SilentlyContinue | Out-Null
Write-Host "Gotowe: Target '$TargetName' z LUN-ami $data / $log" -ForegroundColor Green
