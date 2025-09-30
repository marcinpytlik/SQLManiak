<#
.SYNOPSIS
  Łączy do targetu iSCSI i opcjonalnie inicjalizuje dwa RAW dyski jako E: (Data) i F: (Logs).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$StorIP,
  [switch]$Initialize,
  [int]$DataDiskNumber,
  [int]$LogDiskNumber
)
$ErrorActionPreference='Stop'
Set-Service MSiSCSI -StartupType Automatic
Start-Service MSiSCSI
New-IscsiTargetPortal -TargetPortalAddress $StorIP -ErrorAction SilentlyContinue | Out-Null
$target = Get-IscsiTarget | Select-Object -First 1
if ($target -and $target.IsConnected -eq $false) {
  Connect-IscsiTarget -NodeAddress $target.NodeAddress -IsPersistent $true | Out-Null
}
if (-not $Initialize) { return }
function Init-Format([int]$num,[string]$letter,[string]$label){
  Initialize-Disk -Number $num -PartitionStyle GPT
  New-Partition -DiskNumber $num -DriveLetter $letter -UseMaximumSize | `
    Format-Volume -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel $label -Confirm:$false | Out-Null
}
if ($PSBoundParameters.ContainsKey('DataDiskNumber') -and $PSBoundParameters.ContainsKey('LogDiskNumber')) {
  Init-Format -num $DataDiskNumber -letter 'E' -label 'SQLData'
  Init-Format -num $LogDiskNumber  -letter 'F' -label 'SQLLogs'
} else {
  $raw = Get-Disk | Where-Object PartitionStyle -eq 'RAW' | Sort-Object Size -Descending | Select-Object -First 2
  if ($raw.Count -ne 2) { throw "Nie wykryto dokładnie 2 RAW dysków. Podaj -DataDiskNumber/-LogDiskNumber." }
  Init-Format -num $raw[0].Number -letter 'E' -label 'SQLData'
  Init-Format -num $raw[1].Number -letter 'F' -label 'SQLLogs'
}
Write-Host "E: i F: gotowe (NTFS 64K)" -ForegroundColor Green
