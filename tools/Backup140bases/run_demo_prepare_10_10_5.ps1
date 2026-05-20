param(
    [string]$SqlInstance = "syriusz",
    [string]$ScriptRoot = "."
)

$ErrorActionPreference = "Stop"

$steps = @(
    "01_create_backup_config_tables.sql",
    "02_create_backup_procedure_by_config.sql",
    "09_create_25_test_databases_demo_10_10_5.sql"
)

foreach ($step in $steps) {
    $path = Join-Path $ScriptRoot $step
    if (-not (Test-Path $path)) {
        throw "Nie znaleziono pliku: $path"
    }

    Write-Host "Running: $step" -ForegroundColor Cyan
    sqlcmd -S $SqlInstance -E -b -i $path
}

Write-Host ""
Write-Host "Gotowe. Teraz sprawdź DryRun oraz katalogi C:\backup1, C:\backup2, C:\backup3." -ForegroundColor Green
Write-Host "Realny backup uruchom skryptem: 10_demo_run_full_backup_10_10_5.sql" -ForegroundColor Yellow
