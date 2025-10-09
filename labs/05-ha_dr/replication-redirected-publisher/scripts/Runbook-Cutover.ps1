[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ParamsPath = "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\Params.sample.psd1",
  [switch]$DryRun
)
$P = Import-PowerShellDataFile -Path $ParamsPath

Write-Host "===== MIGRACJA: Redirected Publisher (A → C), B zostaje =====" -ForegroundColor Yellow
Write-Host "Publikacja: $($P.Publication)  | Baza: $($P.PublisherDb)"

function Step($name, [ScriptBlock]$action) {
  Write-Host "---- $name ----" -ForegroundColor Cyan
  if ($DryRun) { Write-Host "(DryRun) Pomijam wykonanie kroku $name"; return }
  & $action
}

Step "Precheck: Inwentaryzacja (A)" { & "$PSScriptRoot\02.Precheck-Inventory.ps1" -P $P }
Step "Ustaw allow_initialize_from_backup (A)" { & "$PSScriptRoot\03.Enable-InitFromBackup.ps1" -P $P }
Write-Host "Upewnij się, że zrealizowano konfigurację zdalnego dystrybutora (A<->C)."
Step "Cutover: Stop agentów + finalny LOG (A)" { & "$PSScriptRoot\05.Cutover-FinalLog.ps1" -P $P }
Step "Kopiowanie backupów z A → C" { & "$PSScriptRoot\01.Copy-Backups.ps1" -P $P }
Step "Restore na C z KEEP_REPLICATION" { & "$PSScriptRoot\06.Restore-OnC.ps1" -P $P }
Step "Redirect publisher na B (A→C)" { & "$PSScriptRoot\07.Redirect-OnB.ps1" -P $P }
Step "Walidacja na C" { & "$PSScriptRoot\08.Validate-OnC.ps1" -P $P }
Step "Start agentów (na A – jeśli tam mieszkają joby)" { & "$PSScriptRoot\09.StartAgents.ps1" -P $P -Where 'A' }
Step "Monitoring (C)" { & "$PSScriptRoot\10.Monitoring.ps1" -P $P -On 'C' }

Write-Host "===== KONIEC CUTOVERU. Opcjonalnie: migracja dystrybutora A → C =====" -ForegroundColor Yellow
