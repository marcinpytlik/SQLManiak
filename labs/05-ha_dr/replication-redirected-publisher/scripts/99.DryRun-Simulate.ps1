[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ParamsPath = "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\Params.sample.psd1"
)
$P = Import-PowerShellDataFile -Path $ParamsPath

Write-Host "=== Symulacja (DryRun) — Redirected Publisher + opcjonalnie move Distributor ===" -ForegroundColor Yellow

function Check-File($path) {
  if (Test-Path $path) {
    $fi = Get-Item $path
    "{0}  SIZE={1}  MOD={2}" -f $fi.FullName, $fi.Length, $fi.LastWriteTime
  } else {
    "BRAK: $path"
  }
}

# Sprawdź spodziewane pliki backupów na A
$preFull = Join-Path $P.BackupShareA "$($P.PublisherDb)_pre_full.bak"
$preLog  = Join-Path $P.BackupShareA "$($P.PublisherDb)_pre_log.trn"
$final   = Join-Path $P.BackupShareA "$($P.PublisherDb)_FINAL_LOG.trn"

Write-Host "[A] Oczekiwane pliki backupów:" -ForegroundColor Cyan
Check-File $preFull
Check-File $preLog
Check-File $final

# Sprawdź miejsce docelowe na C
$dstFull = Join-Path $P.BackupShareC "$($P.PublisherDb)_pre_full.bak"
$dstLog  = Join-Path $P.BackupShareC "$($P.PublisherDb)_pre_log.trn"
$dstFin  = Join-Path $P.BackupShareC "$($P.PublisherDb)_FINAL_LOG.trn"

Write-Host "[C] Docelowe pliki (po kopiowaniu):" -ForegroundColor Cyan
Check-File $dstFull
Check-File $dstLog
Check-File $dstFin

Write-Host "`n=== Kroki, które zostaną wykonane podczas właściwego Runbooka ==="
@(
  "Precheck/Inwentaryzacja na A",
  "Ustawienie allow_initialize_from_backup na publikacji",
  "Okno cięcia: stop agentów na A + finalny log backup",
  "Kopiowanie backupów A→C",
  "RESTORE na C: FULL/LOG + FINAL_LOG WITH KEEP_REPLICATION, RECOVERY",
  "Na B: sp_redirect_publisher A→C",
  "Na C: sp_validate_redirected_publisher + sanity check publikacji",
  "Start agentów (A lub C) i monitoring",
  "Opcjonalnie: migracja dystrybutora A→C (konfiguracja na C, joby, walidacja, cleanup na A)"
) | ForEach-Object { " - " + $_ }

Write-Host "`nUżyj: .\Runbook-Cutover.ps1 -ParamsPath .\Params.psd1 -DryRun aby przejść przez kroki bez wykonania."
