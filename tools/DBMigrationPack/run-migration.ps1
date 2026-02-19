<#
.SYNOPSIS
  Orchestrator: PRECHECK -> BACKUP/RESTORE -> POSTCHECK (+ optional schedule drop).
.DESCRIPTION
  - Reads config.json (for logging dir + db list + endpoints).
  - Runs scripts in order.
  - Stops on first failure (non-zero exit code OR thrown exception).
  - Writes a single pipeline log.

.USAGE
  .\run-migration.ps1 `
    -ConfigPath .\config.json `
    -PrecheckScriptPath .\precheck-migration.ps1 `
    -BackupRestoreScriptPath .\Invoke-SqlBackupRestore..ps1 `
    -PostcheckScriptPath .\postcheck-migration.ps1 `
    -ScheduleDropAfterDays 7 `
    -ScheduleDropScriptPath .\schedule-drop-after-7days.ps1
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string]$ConfigPath,
  [Parameter(Mandatory)] [string]$PrecheckScriptPath,
  [Parameter(Mandatory)] [string]$BackupRestoreScriptPath,
  [Parameter(Mandatory)] [string]$PostcheckScriptPath,

  # Optional: schedule DROP on source after N days (set to 0 to disable)
  [int]$ScheduleDropAfterDays = 0,
  [string]$ScheduleDropScriptPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-File([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { throw "Brak pliku: $p" }
}

Assert-File $ConfigPath
Assert-File $PrecheckScriptPath
Assert-File $BackupRestoreScriptPath
Assert-File $PostcheckScriptPath
if ($ScheduleDropAfterDays -gt 0) {
  if (-not $ScheduleDropScriptPath) { throw "Podaj -ScheduleDropScriptPath gdy -ScheduleDropAfterDays > 0" }
  Assert-File $ScheduleDropScriptPath
}

# Load config
$cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$alsoConsole = ($cfg.logOptions.alsoWriteToConsole -eq $true)

# Prepare pipeline log
$logDir = $cfg.logOptions.logDir
if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$pipelineLog = if ($logDir) { Join-Path $logDir "pipeline_$ts.log" } else { $null }

function Log([string]$Level, [string]$Message) {
  $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
  if ($pipelineLog) { Add-Content -LiteralPath $pipelineLog -Value $line }
  if ($alsoConsole) { Write-Host $line }
}

function Run-Step {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][scriptblock]$Action
  )

  Log "INFO" "STEP START | $Name"
  try {
    & $Action
    $code = $LASTEXITCODE

    # Some scripts might not set LASTEXITCODE; treat non-zero as fail only when set
    if ($code -and $code -ne 0) {
      Log "ERROR" "STEP FAIL | $Name | exitCode=$code"
      throw "Krok '$Name' zakończony błędem (exitCode=$code)."
    }

    Log "OK" "STEP OK   | $Name"
  }
  catch {
    Log "ERROR" "STEP EXCEPTION | $Name | $($_.Exception.Message)"
    throw
  }
}

Log "INFO" "PIPELINE START | source=$($cfg.source) dest=$($cfg.destination) dbs=$($cfg.databases -join ', ')"
if ($pipelineLog) { Log "INFO" "PipelineLog=$pipelineLog" }

# 1) PRECHECK (source) + set READ_ONLY
Run-Step -Name "precheck-migration (source -> READ_ONLY)" -Action {
  & $PrecheckScriptPath -ConfigPath $ConfigPath
}

# 2) BACKUP + RESTORE
Run-Step -Name "Invoke-SqlBackupRestore (backup + restore)" -Action {
  & $BackupRestoreScriptPath -ConfigPath $ConfigPath
}

# 3) POSTCHECK (destination): compat 160 + QS 2GB RW + DB READ_WRITE
Run-Step -Name "postcheck-migration (destination settings)" -Action {
  & $PostcheckScriptPath -ConfigPath $ConfigPath
}

# 4) Optional: schedule DROP on source after N days
if ($ScheduleDropAfterDays -gt 0) {
  Run-Step -Name "schedule-drop-after-$ScheduleDropAfterDays-days (source cleanup)" -Action {
    & $ScheduleDropScriptPath -ConfigPath $ConfigPath -Days $ScheduleDropAfterDays
  }
} else {
  Log "INFO" "SKIP | schedule-drop-after-days disabled (ScheduleDropAfterDays=0)"
}

Log "OK" "PIPELINE DONE | sukces"
if ($pipelineLog) { Write-Host "`nPIPELINE LOG: $pipelineLog" }
