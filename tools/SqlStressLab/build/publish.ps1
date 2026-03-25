$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$publishDir = Join-Path $root "publish\SqlStressLab-win-x64"

if (Test-Path $publishDir) {
    Remove-Item $publishDir -Recurse -Force
}

dotnet publish "$root\src\SqlStressLab.Cli\SqlStressLab.Cli.csproj" `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -o $publishDir

$folders = @(
    "profiles",
    "outputs",
    "logs",
    "sessions",
    "exports",
    "runbooks",
    "templates",
    "policies",
    "hooks"
)

foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force (Join-Path $publishDir $folder) | Out-Null
}

Write-Host "Publish completed:"
Write-Host $publishDir
# session.sql in profiles
#SET NOCOUNT ON;
#SET XACT_ABORT ON;
#SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
#SET LOCK_TIMEOUT 15000;
#SET DEADLOCK_PRIORITY NORMAL;
#SET ANSI_NULLS ON;
#SET ANSI_WARNINGS ON;
#SET QUOTED_IDENTIFIER ON;
#SET ARITHABORT ON;