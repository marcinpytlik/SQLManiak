<# Verify-BackupChain.ps1
Sprawdza możliwość odtworzenia (VERIFYONLY) dla zestawu plików .bak/.trn.
#>
param(
  [string]$Instance = "localhost",
  [string]$Path = "D:\Backups\VLDB"
)
$files = Get-ChildItem -Path $Path -File | Sort-Object Name
foreach ($f in $files) {
  if ($f.Extension -in (".bak",".trn",".dif",".log")) {
    $q = "RESTORE VERIFYONLY FROM DISK = N'${f.FullName.Replace("'", "''")}'"
    Write-Host "VERIFY: $($f.Name)"
    sqlcmd -S $Instance -Q $q
  }
}
