param(
    [string]$SqlInstance = ".",
    [string]$Database = "SnapshotDemoDB",
    [string]$DataPath = "C:\SQL\SnapshotDemo",
    [ValidateSet("Windows","Sql")] [string]$LoginType = "Windows",
    [string]$SqlUser = "",
    [string]$SqlPass = ""
)

Write-Host ">> Tworzenie katalogu $DataPath (jeśli nie istnieje)"
New-Item -ItemType Directory -Path $DataPath -Force | Out-Null

function Invoke-SqlFile {
    param($file)
    $auth = @()
    if ($LoginType -eq "Windows") {
        $auth = @("-E")
    } else {
        $auth = @("-U", $SqlUser, "-P", $SqlPass)
    }
    & sqlcmd -S $SqlInstance @auth -b -v DatabaseName=$Database DataPath=$DataPath SnapshotName="$($Database)_SS" -i $file
    if ($LASTEXITCODE -ne 0) {
        throw "sqlcmd exit code $LASTEXITCODE for $file"
    }
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = Join-Path $root "scripts"

Invoke-SqlFile (Join-Path $scripts "01_CreateDatabase.sql")
Invoke-SqlFile (Join-Path $scripts "02_CreateSnapshot.sql")
Invoke-SqlFile (Join-Path $scripts "03_ModifyData.sql")
Invoke-SqlFile (Join-Path $scripts "04_MonitorGrowth.sql")

Write-Host ">> (Opcjonalnie) uruchom 99_Stress_IndexRebuild.sql jeśli masz Enterprise i chcesz pompować snapshot."
Write-Host ">> Na końcu możesz odtworzyć bazę: 05_RevertFromSnapshot.sql i posprzątać: 06_DropAll.sql"
