param(
    [string]$Server = $env:MSSQL_SERVER,
    [string]$User = $env:MSSQL_USER,
    [string]$Pass = $env:MSSQL_PASS
)

if (-not $Server -or -not $User -or -not $Pass) {
    Write-Host "Ustaw zmienne środowiskowe MSSQL_SERVER, MSSQL_USER, MSSQL_PASS i uruchom ponownie." -ForegroundColor Yellow
    exit 1
}

$files = @(
    ".\sql\00-prereq.sql",
    ".\sql\01-create-data.sql",
    ".\sql\02-proc-and-indexes.sql",
    ".\sql\03-run-scenarios.sql"
)

foreach ($f in $files) {
    Write-Host "==> Running $f" -ForegroundColor Cyan
    & sqlcmd -C -S $Server -U $User -P $Pass -i $f
    if ($LASTEXITCODE -ne 0) { Write-Error "Błąd w $f"; exit 1 }
}

Write-Host "DONE. Teraz sprawdź pliki w folderze sql\dmv lub odpal taski 04-*" -ForegroundColor Green
