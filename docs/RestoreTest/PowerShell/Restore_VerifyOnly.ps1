param(
    [string]$ServerInstance = "localhost",
    [string]$BackupPath     = "D:\Backup",
    [string]$Pattern        = "*.bak"
)

# Weryfikacja integralności plików .bak bez przywracania
Get-ChildItem -Path $BackupPath -Filter $Pattern | ForEach-Object {
    Write-Host "VERIFYONLY: $($_.FullName)"
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Query @"
RESTORE VERIFYONLY FROM DISK = N'$($_.FullName)';
"@
}
