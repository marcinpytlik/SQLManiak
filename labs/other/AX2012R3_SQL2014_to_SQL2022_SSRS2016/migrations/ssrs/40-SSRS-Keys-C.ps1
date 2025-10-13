<# 40-SSRS-Keys-C.ps1
Backup/Restore klucza szyfrowania SSRS 2016 (serwer C).
#>
param(
  [ValidateSet("Backup","Restore")][string]$Action = "Backup",
  [string]$KeyPath = "C:\SSRS_Keys\ssrs_key.snk",
  [string]$Password = "ChangeMe!123"
)

$cfg = Join-Path "${env:ProgramFiles(x86)}" "Microsoft SQL Server\130\Tools\Binn\RSKeyMgmt.exe"
if (!(Test-Path $cfg)) { Write-Error "Nie znaleziono RSKeyMgmt.exe (SSRS 2016)."; exit 1 }

if ($Action -eq "Backup") {
  if (!(Test-Path (Split-Path $KeyPath))) { New-Item -ItemType Directory -Path (Split-Path $KeyPath) | Out-Null }
  & $cfg -e -f $KeyPath -p $Password
  Write-Host "Klucz zapisany: $KeyPath"
} else {
  & $cfg -a -f $KeyPath -p $Password
  Write-Host "Klucz przywrócony."
}
