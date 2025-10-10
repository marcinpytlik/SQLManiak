<# 41-SSRS-Bind-DB.ps1
Tworzy/wiąże bazy ReportServer na B dla SSRS 2016 (C).
Wymaga uprawnień sysadmin na B.
#>
param(
  [string]$ReportServerInstance = "MSSQLSERVER",
  [string]$SqlServerName = "B",
  [string]$DatabaseName = "ReportServer",
  [string]$Mode = "Create" # lub "Bind"
)

# Używamy rsconfig i rsconfigtool zamiennie (w praktyce najlepiej GUI RSCM).
$cfg = Join-Path "${env:ProgramFiles(x86)}" "Microsoft SQL Server\110\Tools\Binn\rsconfig.exe"
if (!(Test-Path $cfg)) { Write-Warning "rsconfig.exe nie znaleziono – użyj GUI Reporting Services Configuration Manager." }
Write-Host "Uwaga: Zalecane wykonanie przez GUI (Database → Create/Change). Skrypt poglądowy."
