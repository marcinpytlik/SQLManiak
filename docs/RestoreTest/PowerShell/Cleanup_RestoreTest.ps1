param(
    [string]$ServerInstance = "localhost",
    [string]$DbName = "DemoDB_Test",
    [string]$DataPath = "D:\SQLData",
    [string]$LogPath = "D:\SQLLog"
)

Write-Host "== Cleanup: dropping database $DbName if exists =="
try {
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "
IF DB_ID('$DbName') IS NOT NULL
BEGIN
    ALTER DATABASE [$DbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$DbName];
END"
} catch {
    Write-Warning "DROP DATABASE failed or not needed: $_"
}

$files = @("$DataPath\$DbName.mdf","$LogPath\$DbName.ldf")
foreach ($f in $files) {
    if (Test-Path $f) {
        try {
            Remove-Item $f -Force
            Write-Host "Removed $f"
        } catch {
            Write-Warning "Cannot remove $f: $_"
        }
    }
}
