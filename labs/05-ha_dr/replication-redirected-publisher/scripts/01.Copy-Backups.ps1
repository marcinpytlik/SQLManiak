param(
  [Parameter(Mandatory)][hashtable]$P
)
# Przykładowe nazwy plików zgodnie z sql/03_backup_commands.sql i 04_cutover...
$files = @(
  "$($P.PublisherDb)_pre_full.bak",
  "$($P.PublisherDb)_pre_log.trn",
  "$($P.PublisherDb)_FINAL_LOG.trn"
)
foreach ($f in $files) {
  $src = Join-Path $P.BackupShareA $f
  $dst = Join-Path $P.BackupShareC $f
  Write-Host "Kopiuję $src -> $dst"
  if (-not (Test-Path (Split-Path $dst))) { New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null }
  Copy-Item -Path $src -Destination $dst -Force
}
Write-Host "Kopiowanie zakończone."
