#requires -Version 7.2
<#
 Test 35: two separate source SQL logins for Docker LAB targets only.
 Uses existing admin PSCredentials and returns a NEW credential map.
 No password output, disk persistence, role escalation to sysadmin.
 WARNING: partial provisioning can remain if second target fails.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][hashtable]$AdminCredentialByServer
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module SqlServer -ErrorAction Stop
Add-Type -AssemblyName Microsoft.Data.SqlClient -ErrorAction Stop
$targets=@('127.0.0.1,15434','127.0.0.1,15435')
$map=@{}
foreach($target in $targets){
 if(-not $AdminCredentialByServer.ContainsKey($target) -or $AdminCredentialByServer[$target] -isnot [PSCredential]){
  throw "Missing administrator PSCredential for $target"
 }
}
foreach($target in $targets){
 $credential=$AdminCredentialByServer[$target]
 $login=if($target.EndsWith('15434')){'dhc_source_collector_lab_1'}else{'dhc_source_collector_lab_2'}
 $b=[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new()
 $b['Data Source']=$target
 $b['Initial Catalog']='master'
 $b['User ID']=$credential.UserName
 $b['Password']=$credential.GetNetworkCredential().Password
 $b['Encrypt']='True'
 $b['Trust Server Certificate']=$true
 $b['Persist Security Info']=$false
 $conn=[Microsoft.Data.SqlClient.SqlConnection]::new($b.ConnectionString)
 try {
  $conn.Open()
  $check=$conn.CreateCommand()
  try {
   $check.CommandText="SELECT COUNT(*) FROM sys.server_principals WHERE name=N'$login';"
   if([int]$check.ExecuteScalar() -ne 0){throw "Source login already exists on $target; refusing password reset."}
  } finally {$check.Dispose()}
  $bytes=[Security.Cryptography.RandomNumberGenerator]::GetBytes(48)
  try {
   $secret=[Convert]::ToBase64String($bytes)+'!aA9'
   $newCred=[PSCredential]::new($login,(ConvertTo-SecureString $secret -AsPlainText -Force))
   $cmd=$conn.CreateCommand()
   try {
    $cmd.CommandText=@"
CREATE LOGIN [$login] WITH PASSWORD=N'$secret', CHECK_POLICY=ON,
 CHECK_EXPIRATION=OFF, DEFAULT_DATABASE=[master];
GRANT VIEW SERVER PERFORMANCE STATE TO [$login];
GRANT VIEW SERVER SECURITY STATE TO [$login];
GRANT VIEW ANY ERROR LOG TO [$login];
"@
    [void]$cmd.ExecuteNonQuery()
   } finally {$cmd.Dispose()}
   $msdb=$conn.CreateCommand()
   try {
    $msdb.CommandText=@"
USE msdb;
CREATE USER [$login] FOR LOGIN [$login];
ALTER ROLE [SQLAgentReaderRole] ADD MEMBER [$login];
"@
    [void]$msdb.ExecuteNonQuery()
   } finally {$msdb.Dispose()}
   $map[$target]=$newCred
   Write-Host "LAB source login $login created on $target; no sysadmin." -ForegroundColor Green
  } finally {
   [Array]::Clear($bytes,0,$bytes.Length)
   $secret=$null
  }
 } catch {
  Write-Warning "Provisioning may be partial on $target. Inspect sys.server_principals and msdb.sys.database_principals; do not rerun blindly."
  throw
 } finally {$conn.Dispose();$b.Clear()}
}
return ,$map
