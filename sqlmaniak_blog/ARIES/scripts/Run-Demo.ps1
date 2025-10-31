param(
    [string]$Server = $env:MSSQL_SERVER,
    [string]$User = $env:MSSQL_USER,
    [string]$Pass = $env:MSSQL_PASS
)

if (-not $Server -or -not $User -or -not $Pass) {
    Write-Host "Ustaw MSSQL_SERVER, MSSQL_USER, MSSQL_PASS i uruchom ponownie." -ForegroundColor Yellow
    exit 1
}

$files = @(
    ".\sql\00-create-db.sql",
    ".\sql\01-transaction-demo.sql",
    ".\sql\02-checkpoint-demo.sql",
    ".\sql\03-recovery-sim.sql"
)

foreach ($f in $files) {
    Write-Host "==> Running $f" -ForegroundColor Cyan
    & sqlcmd -C -S $Server -U $User -P $Pass -i $f
}
Write-Host "DONE. Sprawdź DMV i fn_dblog() w ARIES_Demo." -ForegroundColor Green
