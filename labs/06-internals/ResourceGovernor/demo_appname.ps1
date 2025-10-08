# Demo APP_NAME(): tworzy dwie sesje z różnymi Application Name i pokazuje przypisanie WG
param(
  [string]$Server = "localhost",
  [ValidateSet("Windows","SQL")] [string]$Auth = "Windows",
  [string]$User = "",
  [string]$Password = "",
  [string]$DbName = "TwojaBaza"
)

$ErrorActionPreference = "Stop"

# Wymaga Microsoft.Data.SqlClient lub System.Data.SqlClient
Add-Type -AssemblyName System.Data

function Invoke-Query([string]$cs, [string]$sql){
  $conn = New-Object System.Data.SqlClient.SqlConnection $cs
  $conn.Open()
  $cmd = $conn.CreateCommand()
  $cmd.CommandText = $sql
  $r = $cmd.ExecuteReader()
  $dt = New-Object System.Data.DataTable
  $dt.Load($r)
  $conn.Close()
  return $dt
}

$baseCs = "Server={0};Database={1};{2}" -f $Server, $DbName, ($Auth -eq "SQL" ? ("User ID="+$User+";Password="+$Password+";") : "Integrated Security=true;")

$csLab  = $baseCs + "Application Name=TwojaApp-LAB;"
$csProd = $baseCs + "Application Name=TwojaApp-PROD;"

$verifySql = @"
SELECT @@SPID AS spid, APP_NAME() AS app_name, ORIGINAL_LOGIN() AS login_name,
       DB_NAME() AS default_db,
       wg.name AS workload_group, rp.name AS pool_name
FROM sys.dm_exec_sessions s
JOIN sys.dm_resource_governor_workload_groups wg ON s.group_id = wg.group_id
JOIN sys.dm_resource_governor_resource_pools  rp ON wg.pool_id = rp.pool_id
WHERE s.session_id = @@SPID;
"@

"== Sesja LAB =="
$dt1 = Invoke-Query -cs $csLab -sql $verifySql
$dt1 | Format-Table -AutoSize

"== Sesja PROD =="
$dt2 = Invoke-Query -cs $csProd -sql $verifySql
$dt2 | Format-Table -AutoSize

"`nUwaga: APP_NAME() jest nadawane przy logowaniu – zmiana wymaga nowego połączenia."
