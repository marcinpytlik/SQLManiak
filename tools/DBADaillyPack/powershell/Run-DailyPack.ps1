[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$ConfigPath,

  # folder z plikami .sql (domyślnie folder skryptu)
  [string]$SqlDir,

  # Jeśli chcesz pominąć setup (00_) np. po pierwszym uruchomieniu
  [switch]$SkipSetup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Helper (musi być po param)
. "$PSScriptRoot\SqlInventory.Helpers.ps1"
# Auto-detect SqlDir, jeśli nie podano
if ([string]::IsNullOrWhiteSpace($SqlDir)) {
  $cand1 = Join-Path $PSScriptRoot 'sql'                                 # ...\powershell\sql
  $cand2 = Join-Path (Split-Path -Parent $PSScriptRoot) 'sql'            # ...\sql (piętro wyżej)
  if (Test-Path $cand1) { $SqlDir = $cand1 }
  elseif (Test-Path $cand2) { $SqlDir = $cand2 }
  else { throw "Nie znaleziono folderu 'sql'. Sprawdź lokalizację lub podaj -SqlDir." }
}
# -------------------------
# Load config
# -------------------------
$config = Import-InvConfig -ConfigPath $ConfigPath

# Root output folder (z configu)
$rootOut = "C:\temp\SqlInventory"
if ($config.output -and $config.output.folder) { $rootOut = [string]$config.output.folder }
Ensure-InvFolder -Path $rootOut

# DailyPack output: C:\temp\SqlInventory\DailyPack\YYYY-MM-DD_HH-mm
$runStamp = Get-Date -Format "yyyy-MM-dd_HH-mmss"
$dailyOutRoot = Join-Path $rootOut ("DailyPack\" + $runStamp)
Ensure-InvFolder -Path $dailyOutRoot

$globalLog = Join-Path $dailyOutRoot "DailyPack.log"
"[$(Get-Date -Format s)] START DailyPack" | Out-File -FilePath $globalLog -Encoding UTF8

function Write-Log {
  param([string]$Message)
  $line = "[{0}] {1}" -f (Get-Date -Format "s"), $Message
  $line | Out-File -FilePath $globalLog -Append -Encoding UTF8
  Write-Host $Message
}

function Invoke-SqlFileToCsv {
  param(
    [Parameter(Mandatory=$true)][hashtable]$Conn,
    [Parameter(Mandatory=$true)][string]$SqlFilePath,
    [Parameter(Mandatory=$true)][string]$OutCsvPath,
    [Parameter(Mandatory=$true)][string]$OutTxtPath
  )

  $sqlText = Get-Content -LiteralPath $SqlFilePath -Raw

  # helper do zapisu jednego rowsetu
  function Save-Rowset([object]$rowset, [string]$csv, [string]$txt, [string]$label){
    $rows = @($rowset) # <- zawsze tablica (0..n), więc .Count działa
    $count = $rows.Count

    $t = @()
    $t += "File: $SqlFilePath"
    $t += "Server: $($Conn.ServerInstance)  Database: $($Conn.Database)"
    if ($label) { $t += "Resultset: $label" }
    $t += "Rows: $count"
    $t += ""
    if ($count -gt 0) { $t += ($rows | Format-Table -AutoSize | Out-String -Width 4096) }
    else { $t += "(no rows / no rowset)" }

    $t -join "`r`n" | Out-File -LiteralPath $txt -Encoding UTF8

    if ($count -gt 0) {
      $rows | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8
    } else {
      "" | Out-File -LiteralPath $csv -Encoding UTF8
    }
  }

  try {
    $res = Invoke-Sqlcmd @Conn -Query $sqlText

    # 1) brak wyników (DDL itp.) -> traktujemy jako OK
    if ($null -eq $res) {
      Save-Rowset @() $OutCsvPath $OutTxtPath "0"
      return $true
    }

    # 2) wiele resultsetów -> DataSet
    if ($res -is [System.Data.DataSet]) {
      $i = 0
      foreach ($tbl in $res.Tables) {
        $i++
        $csv = $OutCsvPath -replace '\.csv$', "_$i.csv"
        $txt = $OutTxtPath -replace '\.txt$', "_$i.txt"
        Save-Rowset $tbl $csv $txt "$i"
      }
      return $true
    }

    # 3) standardowy jeden rowset
    Save-Rowset $res $OutCsvPath $OutTxtPath "1"
    return $true
  }
  catch {
    $msg = $_.Exception.Message
    Write-Log ("ERROR Invoke-SqlFileToCsv: {0}" -f $msg)

    @(
      "File: $SqlFilePath"
      "Server: $($Conn.ServerInstance)  Database: $($Conn.Database)"
      "ERROR: $msg"
    ) -join "`r`n" | Out-File -LiteralPath $OutTxtPath -Encoding UTF8

    "" | Out-File -LiteralPath $OutCsvPath -Encoding UTF8
    return $false
  }
}
# -------------------------
# SQL files list
# -------------------------
$files = @()

if (-not $SkipSetup) {
  $files += "00_Setup_Waits_Baseline_Table.sql"
}

$files += @(
  "01_Backup_Compliance.sql",
  "02_Agent_Jobs_Health.sql",
  "03_Tempdb_Health.sql",
  "04_Health_Signals.sql",
  "05_Waits_Baseline_And_Delta.sql",
  "06_IO_Latency_And_Volumes.sql",
  "07_Blocking_And_LongRunning.sql",
  "08_Errorlog_Scan.sql",
  "09_Audit_Config_Read.sql"
)

# Validate files exist
foreach ($f in $files) {
  $p = Join-Path $SqlDir $f
  if (-not (Test-Path -LiteralPath $p)) {
    throw "Brak pliku SQL: $p"
  }
}

# -------------------------
# Run for each server
# -------------------------
foreach ($sv in $config.servers) {
  $endpoint = [string]$sv.name
  $alias = if ($sv.alias) { [string]$sv.alias } else { $endpoint }

  $serverOut = Join-Path $dailyOutRoot $alias
  Ensure-InvFolder -Path $serverOut

  Write-Log ("==> SERVER: {0} ({1})" -f $alias, $endpoint)

  try {
    # Connection params from helper (Encrypt compat, auth from config, timeout, etc.)
   $conn = New-InvSqlConnParams -ServerCfg $sv -Config $config -Database "master"

    # Daily pack SQL zwykle czyta msdb/sys, więc master OK
    $conn.Database = "master"

    foreach ($f in $files) {
      $src = Join-Path $SqlDir $f
      $base = [IO.Path]::GetFileNameWithoutExtension($src)

      $outCsv = Join-Path $serverOut ($base + ".csv")
      $outTxt = Join-Path $serverOut ($base + ".txt")

      Write-Log ("   RUN: {0}" -f $f)

      $ok = Invoke-SqlFileToCsv -Conn $conn -SqlFilePath $src -OutCsvPath $outCsv -OutTxtPath $outTxt
      if ($ok) {
        Write-Log ("   OK : {0}" -f $base)
      } else {
        Write-Log ("   ERR: {0}" -f $base)
      }
    }
  }
  catch {
    Write-Log ("FATAL on {0}: {1}" -f $endpoint, $_.Exception.Message)
    continue
  }
}

Write-Log "DONE"
Write-Host ("OK -> {0}" -f $dailyOutRoot)