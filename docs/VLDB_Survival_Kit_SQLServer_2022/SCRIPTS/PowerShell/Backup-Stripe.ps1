<# Backup-Stripe.ps1
PARAMETRY: dostosuj $Instance, $DbName, $TargetDir, $Stripes, $Encrypt.
#>
param(
    [string]$Instance = "localhost",
    [string]$DbName   = "VLDB",
    [string]$TargetDir = "D:\Backups\VLDB",
    [int]$Stripes = 4,
    [switch]$Compress = $true,
    [switch]$Encrypt = $true,
    [string]$CertName = "BackupCert"
)
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
$devices = @()
for ($i=1; $i -le $Stripes; $i++) {
    $devices += "TO DISK='$TargetDir\${DbName}_FULL_$timestamp.part$i.bak'"
}
$with = @()
if ($Compress) { $with += "COMPRESSION" }
if ($Encrypt)  { $with += "ENCRYPTION(ALGORITHM = AES_256, SERVER CERTIFICATE = $CertName)" }
$with += "STATS = 30"
$withClause = $with -join ", "

$backupCmd = "BACKUP DATABASE [$DbName] " + ($devices -join " , ") + " WITH $withClause;"
sqlcmd -S $Instance -Q $backupCmd
