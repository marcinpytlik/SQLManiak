<# 
Preflight sprawdza dostępność serwerów A/B/C, uprawnienia i foldery.
Uruchamiaj w PowerShell jako Administrator.
#>

param(
  [string]$EnvFile = "$(Split-Path $PSScriptRoot -Parent)\templates\env.json"
)

if (!(Test-Path $EnvFile)) { Write-Error "Brak pliku env.json. Skopiuj templates\env.sample.json → env.json i uzupełnij." ; exit 1 }
$env = Get-Content $EnvFile | ConvertFrom-Json

Write-Host "== Preflight ==" -ForegroundColor Cyan

# Pingi
'Ping A','Ping B','Ping C' | ForEach-Object { Write-Host $_ }
foreach ($s in @('A','B','C')) {
  $target = $env.$s.sql_instance
  if (-not $target) { $target = $env.$s.ssrs_url }
  $name = if ($s -eq 'C') {'C (SSRS)'} else {$s}
  if (Test-Connection -ComputerName ($env.$s.sql_instance) -Count 1 -Quiet) {
    Write-Host "$name OK" -ForegroundColor Green
  } else {
    Write-Warning "$name nieosiągalny przez ping"
  }
}

# Share na backupy
if ($env.A.backup_share -and (Test-Path $env.A.backup_share)) {
  Write-Host "Backup share OK: $($env.A.backup_share)" -ForegroundColor Green
} else {
  Write-Warning "Backup share niedostępny: $($env.A.backup_share)"
}

# Uprawnienia do ścieżek na B
foreach ($p in @($env.B.data_path,$env.B.log_path)) {
  if (!(Test-Path $p)) { 
    Write-Host "Tworzę $p"
    New-Item -ItemType Directory -Path $p | Out-Null
  }
}

Write-Host "Preflight zakończony."
