<#
Get-FleetHardwareReport.ps1
Zbiera BIOS + firmware (jeśli dostępne) + UEFI/SecureBoot + OS/model/płyta
z wielu serwerów przez WinRM i zapisuje:
- per-host TXT
- zbiorczy CSV + JSON

Użycie:
.\Get-FleetHardwareReport.ps1 -ServerList .\servers.txt -OutDir .\out -ThrottleLimit 16

Wymagania:
- WinRM włączony na serwerach (domyślnie w domenie zwykle działa)
- uprawnienia do remoting (najlepiej admin na serwerach)
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ServerList,

  [string]$OutDir = ".\out",

  [int]$ThrottleLimit = 16,

  [int]$TimeoutSec = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
}

function Read-Servers([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Nie znaleziono pliku listy serwerów: $path"
  }

  Get-Content -LiteralPath $path |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith("#") } |
    Sort-Object -Unique
}

# --------- Remote collector (runs on each server) ----------
$collectScript = {
  param([int]$timeoutSec)

  Set-StrictMode -Version Latest
  $ErrorActionPreference = "Stop"

  function Try-GetCim([string]$className, [string]$ns = "root\cimv2") {
    try {
      $cls = Get-CimClass -ClassName $className -Namespace $ns -ErrorAction Stop
      if ($null -ne $cls) {
        return Get-CimInstance -ClassName $className -Namespace $ns -ErrorAction Stop
      }
    } catch { return $null }
    return $null
  }

  function Get-FirmwareType {
    $code = @"
using System;
using System.Runtime.InteropServices;

public static class FirmwareUtil {
  [DllImport("kernel32.dll", SetLastError=true)]
  public static extern bool GetFirmwareType(out uint FirmwareType);
}
"@
    try { Add-Type -TypeDefinition $code -ErrorAction Stop | Out-Null } catch {}
    $t = 0
    $ok = [FirmwareUtil]::GetFirmwareType([ref]$t)
    if (-not $ok) { return "Unknown" }
    switch ($t) {
      1 { "BIOS (Legacy)" }
      2 { "UEFI" }
      default { "Unknown ($t)" }
    }
  }

  # --- Collect base info ---
  $os  = Get-CimInstance Win32_OperatingSystem
  $cs  = Get-CimInstance Win32_ComputerSystem
  $bb  = Get-CimInstance Win32_BaseBoard
  $bios = Get-CimInstance Win32_BIOS

  $installDate = $null
  $lastBoot = $null
  $biosDate = $null

  try { $installDate = [Management.ManagementDateTimeConverter]::ToDateTime($os.InstallDate) } catch {}
  try { $lastBoot   = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime) } catch {}
  try { $biosDate   = [Management.ManagementDateTimeConverter]::ToDateTime($bios.ReleaseDate) } catch {}

  # --- Win32_Firmware (if exists) ---
  $fwDump = $null
  $fw = Try-GetCim -className "Win32_Firmware" -ns "root\cimv2"
  if ($fw) {
    $fwDump = ($fw | Select-Object * | Format-List * | Out-String).Trim()
  } else {
    $fwDump = "Win32_Firmware: class not available (common on many Windows builds)."
  }

  # --- UEFI / Secure Boot ---
  $firmwareType = Get-FirmwareType
  $secureBoot = $null
  try { $secureBoot = Confirm-SecureBootUEFI } catch { $secureBoot = "Unknown ($($_.Exception.Message))" }

  # Return one object (summary + fwDump)
  [pscustomobject]@{
    ComputerName = $env:COMPUTERNAME
    Domain       = $cs.Domain
    Manufacturer = $cs.Manufacturer
    Model        = $cs.Model

    OS           = $os.Caption
    OSVersion    = $os.Version
    BuildNumber  = $os.BuildNumber
    InstallDate  = $installDate
    LastBootUp   = $lastBoot

    BaseBoard    = "$($bb.Manufacturer) $($bb.Product)"
    BoardSerial  = $bb.SerialNumber

    BIOSVendor        = $bios.Manufacturer
    SMBIOSBIOSVersion = $bios.SMBIOSBIOSVersion
    BIOSVersion       = ($bios.BIOSVersion -join ", ")
    BIOSSerial         = $bios.SerialNumber
    BIOSReleaseDate    = $biosDate

    FirmwareType = $firmwareType
    SecureBoot   = $secureBoot

    FirmwareRaw  = $fwDump
  }
}

# --------- Local output prep ----------
Ensure-Dir $OutDir
$perHostDir = Join-Path $OutDir "per_host"
Ensure-Dir $perHostDir

$ts = (Get-Date).ToString("yyyyMMdd_HHmmss")
$csvOut  = Join-Path $OutDir "hardware_inventory_$ts.csv"
$jsonOut = Join-Path $OutDir "hardware_inventory_$ts.json"

$servers = Read-Servers $ServerList
if (-not $servers -or $servers.Count -eq 0) { throw "Lista serwerów jest pusta." }

Write-Host "Serwerów do sprawdzenia: $($servers.Count)" -ForegroundColor Cyan
Write-Host "Output: $OutDir" -ForegroundColor Cyan
Write-Host "Per-host TXT: $perHostDir" -ForegroundColor Cyan

# --------- Collector runner ----------
$results = New-Object System.Collections.Generic.List[object]

$runOne = {
  param($server)

  $start = Get-Date
  try {
    # szybki sanity-check WinRM
    Test-WSMan -ComputerName $server -ErrorAction Stop | Out-Null

    $data = Invoke-Command -ComputerName $server -ScriptBlock $collectScript -ArgumentList $TimeoutSec -ErrorAction Stop

    # dołącz meta
    $meta = [pscustomobject]@{
      Target       = $server
      Success      = $true
      Error        = $null
      CollectedAt  = Get-Date
      DurationMs   = [math]::Round((New-TimeSpan -Start $start -End (Get-Date)).TotalMilliseconds, 0)
    }

    # zwróć łączony obiekt
    [pscustomobject]@{
      Meta = $meta
      Data = $data
    }
  } catch {
    [pscustomobject]@{
      Meta = [pscustomobject]@{
        Target      = $server
        Success     = $false
        Error       = $_.Exception.Message
        CollectedAt = Get-Date
        DurationMs  = [math]::Round((New-TimeSpan -Start $start -End (Get-Date)).TotalMilliseconds, 0)
      }
      Data = $null
    }
  }
}

# PS7: równolegle; PS5.1: sekwencyjnie
$psMajor = $PSVersionTable.PSVersion.Major
if ($psMajor -ge 7) {
  Write-Host "Tryb: równoległy (PowerShell $psMajor)" -ForegroundColor Green
  $jobs = $servers | ForEach-Object -Parallel {
    # przekazanie zmiennych do runspace
    $server = $_
    & $using:runOne $server
  } -ThrottleLimit $ThrottleLimit

  foreach ($j in $jobs) { $results.Add($j) | Out-Null }
} else {
  Write-Host "Tryb: sekwencyjny (PowerShell $psMajor) – dla równoległości użyj PS7" -ForegroundColor Yellow
  foreach ($s in $servers) {
    Write-Host "-> $s" -ForegroundColor DarkCyan
    $r = & $runOne $s
    $results.Add($r) | Out-Null
  }
}

# --------- Write per-host TXT + build aggregate ---------
$aggregate = New-Object System.Collections.Generic.List[object]

foreach ($r in $results) {
  $target = $r.Meta.Target
  $safeName = ($target -replace '[^a-zA-Z0-9\.\-_]','_')
  $txtPath = Join-Path $perHostDir "hardware_$safeName.txt"

  if (-not $r.Meta.Success) {
    @(
      ("="*80),
      "TARGET: $target",
      "STATUS: FAIL",
      "ERROR : $($r.Meta.Error)",
      "WHEN  : $($r.Meta.CollectedAt)",
      ("="*80)
    ) | Out-File -FilePath $txtPath -Encoding UTF8

    $aggregate.Add([pscustomobject]@{
      Target       = $target
      Success      = $false
      Error        = $r.Meta.Error
      CollectedAt  = $r.Meta.CollectedAt
      DurationMs   = $r.Meta.DurationMs
      ComputerName = $null
      Domain       = $null
      Manufacturer = $null
      Model        = $null
      OS           = $null
      OSVersion    = $null
      BuildNumber  = $null
      BIOSVendor   = $null
      SMBIOSBIOSVersion = $null
      BIOSSerial   = $null
      BIOSReleaseDate = $null
      FirmwareType = $null
      SecureBoot   = $null
      BaseBoard    = $null
      BoardSerial  = $null
    }) | Out-Null

    continue
  }

  $d = $r.Data

  # per-host TXT
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("="*80) | Out-Null
  $lines.Add("TARGET       : $target") | Out-Null
  $lines.Add("COLLECTED AT : $($r.Meta.CollectedAt)") | Out-Null
  $lines.Add("DURATION MS  : $($r.Meta.DurationMs)") | Out-Null
  $lines.Add("="*80) | Out-Null
  $lines.Add("") | Out-Null

  $lines.Add("HOST / OS") | Out-Null
  $lines.Add("-"*80) | Out-Null
  $lines.Add(("ComputerName : {0}" -f $d.ComputerName)) | Out-Null
  $lines.Add(("Domain       : {0}" -f $d.Domain)) | Out-Null
  $lines.Add(("Manufacturer : {0}" -f $d.Manufacturer)) | Out-Null
  $lines.Add(("Model        : {0}" -f $d.Model)) | Out-Null
  $lines.Add(("OS           : {0}" -f $d.OS)) | Out-Null
  $lines.Add(("OSVersion    : {0}" -f $d.OSVersion)) | Out-Null
  $lines.Add(("BuildNumber  : {0}" -f $d.BuildNumber)) | Out-Null
  $lines.Add(("InstallDate  : {0}" -f $d.InstallDate)) | Out-Null
  $lines.Add(("LastBootUp   : {0}" -f $d.LastBootUp)) | Out-Null
  $lines.Add(("BaseBoard    : {0}" -f $d.BaseBoard)) | Out-Null
  $lines.Add(("BoardSerial  : {0}" -f $d.BoardSerial)) | Out-Null
  $lines.Add("") | Out-Null

  $lines.Add("BIOS (Win32_BIOS)") | Out-Null
  $lines.Add("-"*80) | Out-Null
  $lines.Add(("BIOSVendor        : {0}" -f $d.BIOSVendor)) | Out-Null
  $lines.Add(("SMBIOSBIOSVersion : {0}" -f $d.SMBIOSBIOSVersion)) | Out-Null
  $lines.Add(("BIOSVersion       : {0}" -f $d.BIOSVersion)) | Out-Null
  $lines.Add(("BIOSSerial        : {0}" -f $d.BIOSSerial)) | Out-Null
  $lines.Add(("BIOSReleaseDate   : {0}" -f $d.BIOSReleaseDate)) | Out-Null
  $lines.Add("") | Out-Null

  $lines.Add("UEFI / Secure Boot") | Out-Null
  $lines.Add("-"*80) | Out-Null
  $lines.Add(("FirmwareType : {0}" -f $d.FirmwareType)) | Out-Null
  $lines.Add(("SecureBoot   : {0}" -f $d.SecureBoot)) | Out-Null
  $lines.Add("") | Out-Null

  $lines.Add("Win32_Firmware (raw)") | Out-Null
  $lines.Add("-"*80) | Out-Null
  $lines.Add($d.FirmwareRaw) | Out-Null
  $lines.Add("") | Out-Null

  $lines | Out-File -FilePath $txtPath -Encoding UTF8

  # aggregate (summary only, bez FirmwareRaw żeby CSV nie puchł)
  $aggregate.Add([pscustomobject]@{
    Target       = $target
    Success      = $true
    Error        = $null
    CollectedAt  = $r.Meta.CollectedAt
    DurationMs   = $r.Meta.DurationMs

    ComputerName = $d.ComputerName
    Domain       = $d.Domain
    Manufacturer = $d.Manufacturer
    Model        = $d.Model
    OS           = $d.OS
    OSVersion    = $d.OSVersion
    BuildNumber  = $d.BuildNumber

    BIOSVendor        = $d.BIOSVendor
    SMBIOSBIOSVersion = $d.SMBIOSBIOSVersion
    BIOSSerial        = $d.BIOSSerial
    BIOSReleaseDate   = $d.BIOSReleaseDate

    FirmwareType = $d.FirmwareType
    SecureBoot   = $d.SecureBoot

    BaseBoard    = $d.BaseBoard
    BoardSerial  = $d.BoardSerial

    PerHostFile  = $txtPath
  }) | Out-Null
}

# export aggregate
$aggregate | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $csvOut
$aggregate | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonOut -Encoding UTF8

Write-Host ""
Write-Host "DONE ✅" -ForegroundColor Green
Write-Host "CSV : $csvOut" -ForegroundColor Cyan
Write-Host "JSON: $jsonOut" -ForegroundColor Cyan
Write-Host "TXT : $perHostDir" -ForegroundColor Cyan