Param(
  [string]$Path = "C:\ReplLogs"
)
# Tworzy folder na logi agentów replikacji i nadaje Everyone:RX (opcjonalnie zawęź wg polityki)
if (-not (Test-Path $Path)) {
  New-Item -Path $Path -ItemType Directory | Out-Null
  Write-Host "[OK] Utworzono $Path"
} else {
  Write-Host "[OK] Istnieje $Path"
}
