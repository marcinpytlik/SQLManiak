param(
    [string]$Server = $env:MSSQL_SERVER,
    [string]$User = $env:MSSQL_USER,
    [string]$Pass = $env:MSSQL_PASS,
    [int]$Parallel = 4
)

if (-not $Server -or -not $User -or -not $Pass) {
    Write-Host "Ustaw zmienne MSSQL_SERVER, MSSQL_USER, MSSQL_PASS i uruchom ponownie." -ForegroundColor Yellow
    exit 1
}

Write-Host "== Inspect before ==" -ForegroundColor Cyan
& sqlcmd -C -S $Server -U $User -P $Pass -i .\sql\00-inspect-tempdb.sql

Write-Host "== Generate Pressure ==" -ForegroundColor Cyan
& sqlcmd -C -S $Server -U $User -P $Pass -i .\sql\01-generate-pressure.sql

Write-Host "== Inspect after ==" -ForegroundColor Cyan
& sqlcmd -C -S $Server -U $User -P $Pass -i .\sql\00-inspect-tempdb.sql

Write-Host "== Optional: Contention Demo in parallel ==" -ForegroundColor Cyan
$jobs = @()
for ($i=1; $i -le $Parallel; $i++) {
    $jobs += Start-Job -ScriptBlock {
        param($S,$U,$P)
        & sqlcmd -C -S $S -U $U -P $P -i ".\sql\02-contention-demo.sql"
    } -ArgumentList $Server,$User,$Pass
}
if ($jobs.Count -gt 0) { Receive-Job -Job $jobs -Wait -AutoRemoveJob | Out-Null }

Write-Host "DONE." -ForegroundColor Green
