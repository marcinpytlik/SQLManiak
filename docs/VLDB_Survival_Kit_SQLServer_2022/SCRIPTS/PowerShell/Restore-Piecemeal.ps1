<# Restore-Piecemeal.ps1
Przykład piecemeal restore: PRIMARY + FG_HOT, potem dogrywanie pozostałych.
#>
param(
    [string]$Instance = "localhost",
    [string]$DbName   = "VLDB",
    [string]$BackupDir = "D:\Backups\VLDB"
)

# Przywróć PRIMARY + FG_HOT do NORECOVERY (przyklad ze stripe 4)
$sql = @"
RESTORE DATABASE [$DbName]
FILEGROUP = 'PRIMARY',
FILEGROUP = 'FG_HOT'
FROM DISK = '$BackupDir\${DbName}_FULL_*.part1.bak',
     DISK = '$BackupDir\${DbName}_FULL_*.part2.bak',
     DISK = '$BackupDir\${DbName}_FULL_*.part3.bak',
     DISK = '$BackupDir\${DbName}_FULL_*.part4.bak'
WITH NORECOVERY, STATS=30;
-- Tu DIFF i LOG-i dla tych FG...
RESTORE DATABASE [$DbName] WITH RECOVERY;
"@
sqlcmd -S $Instance -Q $sql
