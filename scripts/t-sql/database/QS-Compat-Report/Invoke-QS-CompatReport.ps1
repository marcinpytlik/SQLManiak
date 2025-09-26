
param(
    [Parameter(Mandatory=$true)][string]$Server,
    [Parameter(Mandatory=$true)][string]$Database,
    [Parameter(Mandatory=$true)][string]$BeforeStart,
    [Parameter(Mandatory=$true)][string]$BeforeEnd,
    [Parameter(Mandatory=$true)][string]$AfterStart,
    [Parameter(Mandatory=$true)][string]$AfterEnd
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root "out"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# Wczytaj treść SQL i podmień okna czasowe + USE
$sqlPath = Join-Path $root "QS_Compat_Report.sql"
$sql = Get-Content -Path $sqlPath -Raw

# Proste podmiany — zakładamy, że w skrypcie istnieją stałe linie z DATETIME2
$sql = $sql -replace "USE \[.*?\];", "USE [$Database];"
$sql = $sql -replace "DECLARE @BeforeStart datetime2 = '.*?';", "DECLARE @BeforeStart datetime2 = '$BeforeStart';"
$sql = $sql -replace "DECLARE @BeforeEnd   datetime2 = '.*?';", "DECLARE @BeforeEnd   datetime2 = '$BeforeEnd';"
$sql = $sql -replace "DECLARE @AfterStart  datetime2 = '.*?';", "DECLARE @AfterStart  datetime2 = '$AfterStart';"
$sql = $sql -replace "DECLARE @AfterEnd    datetime2 = '.*?';", "DECLARE @AfterEnd    datetime2 = '$AfterEnd';"

# Zapisz tymczasowy plik do wykonania
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$tmpPath = Join-Path $outDir ("QS_Compat_Report_expanded_" + $ts + ".sql")
$sql | Set-Content -Path $tmpPath -Encoding UTF8

# Uruchom sqlcmd
$logPath = Join-Path $outDir ("run-" + $ts + ".log")
Write-Host "Running sqlcmd..."
& sqlcmd -S $Server -d $Database -i $tmpPath -b -r 1 *>&1 | Tee-Object -FilePath $logPath

Write-Host "Done. Log: $logPath"
