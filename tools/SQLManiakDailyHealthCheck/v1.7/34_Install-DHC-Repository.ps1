#requires -Version 7.2
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$ServerInstance,
 [Parameter(Mandatory)][PSCredential]$AdministratorCredential,
 [Parameter(Mandatory)][string]$CollectorLogin,
 [PSCredential]$NewCollectorCredential,
 [switch]$TrustServerCertificate,
 [switch]$Apply
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Add-Type -AssemblyName Microsoft.Data.SqlClient -ErrorAction Stop
if($CollectorLogin -notmatch '^[A-Za-z][A-Za-z0-9_]{2,127}$'){throw 'Use a simple SQL login name (letters, numbers, underscore).'}
if($NewCollectorCredential -and $NewCollectorCredential.UserName -cne $CollectorLogin){throw 'Credential username does not match CollectorLogin.'}
function Open-Connection([string]$db){
 $b=[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new()
 $b['Data Source']=$ServerInstance
 $b['Initial Catalog']=$db
 $b['User ID']=$AdministratorCredential.UserName
 $b['Password']=$AdministratorCredential.GetNetworkCredential().Password
 $b['Encrypt']='True'
 $b['Trust Server Certificate']=[bool]$TrustServerCertificate
 $b['Connect Timeout']=10
 $b['Persist Security Info']=$false
 $c=[Microsoft.Data.SqlClient.SqlConnection]::new($b.ConnectionString)
 try{$c.Open();return $c}catch{$c.Dispose();throw}finally{$b.Clear()}
}
function Exec-Sql([Microsoft.Data.SqlClient.SqlConnection]$conn,[string]$sql){
 $cmd=$conn.CreateCommand()
 try{$cmd.CommandTimeout=180;$cmd.CommandText=$sql;[void]$cmd.ExecuteNonQuery()}finally{$cmd.Dispose()}
}
function Ensure-Login([Microsoft.Data.SqlClient.SqlConnection]$conn){
 $cmd=$conn.CreateCommand()
 try{
  $cmd.CommandText="SELECT type_desc,ISNULL(IS_SRVROLEMEMBER(N'sysadmin',@name),0) FROM sys.server_principals WHERE name=@name"
  [void]$cmd.Parameters.Add('@name',[System.Data.SqlDbType]::NVarChar,128)
  $cmd.Parameters['@name'].Value=$CollectorLogin
  $reader=$cmd.ExecuteReader()
  try {
   if($reader.Read()){
    if($reader.GetString(0) -ne 'SQL_LOGIN' -or $reader.GetInt32(1) -ne 0){throw 'Existing login is not a non-sysadmin SQL login.'}
    return
   }
  }finally{$reader.Dispose()}
 }finally{$cmd.Dispose()}
 if(-not $NewCollectorCredential){throw "Missing SQL login $CollectorLogin. Provide -NewCollectorCredential to create it."}
 $secret=$NewCollectorCredential.GetNetworkCredential().Password
 try{
  if($secret.Length -lt 16){throw 'Password must be at least 16 characters.'}
  $escaped=$secret.Replace("'","''")
  Exec-Sql $conn "CREATE LOGIN [$CollectorLogin] WITH PASSWORD=N'$escaped', CHECK_POLICY=ON, CHECK_EXPIRATION=OFF;"
 }finally{$secret=$null;$escaped=$null}
}

# Repository installer: preview by default, no delete or scheduler.
$files=@('01_Repository.sql','04_MonitoredServers.sql','08_ExecutionLog.sql',
         '09_MonitoringStatus.sql','12_TryStartExecution.sql',
         '14_RunningWatch.sql','42_CapacityRepository.sql','44_CapacityForecast.sql',
         '20_RepositoryLeastPrivilege.sql')
foreach($file in $files){
 if(-not(Test-Path -LiteralPath (Join-Path $PSScriptRoot $file) -PathType Leaf)){throw "Missing prerequisite: $file"}
}
if(-not $Apply){
 Write-Host "PREVIEW: deploy $($files -join ', ') to $ServerInstance and map $CollectorLogin to dhc_collector."
 return
}
Import-Module SqlServer -ErrorAction Stop
$conn=Open-Connection 'master'
try {
 if([int]($conn.ServerVersion.Split('.')[0]) -lt 16){throw 'SQL Server 2022+ required; earlier releases need separate review.'}
 $b=[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new()
 $b['Data Source']=$ServerInstance
 $b['Initial Catalog']='master'
 $b['User ID']=$AdministratorCredential.UserName
 $b['Password']=$AdministratorCredential.GetNetworkCredential().Password
 $b['Encrypt']='True'
 $b['Trust Server Certificate']=[bool]$TrustServerCertificate
 try{
  foreach($file in $files){
   Write-Host "Deploying $file"
   Invoke-Sqlcmd -ConnectionString $b.ConnectionString -InputFile (Join-Path $PSScriptRoot $file) -AbortOnError -ErrorAction Stop -QueryTimeout 180 | Out-Null
  }
 }finally{$b.Clear()}
 Ensure-Login $conn
}finally{$conn.Dispose()}
$conn=Open-Connection 'SQLManiakHealthHistory'
try {
 Exec-Sql $conn @"
IF DATABASE_PRINCIPAL_ID(N'$CollectorLogin') IS NULL CREATE USER [$CollectorLogin] FOR LOGIN [$CollectorLogin];
IF NOT EXISTS (
 SELECT 1 FROM sys.database_role_members m
 JOIN sys.database_principals r ON r.principal_id=m.role_principal_id
 JOIN sys.database_principals u ON u.principal_id=m.member_principal_id
 WHERE r.name=N'dhc_collector' AND u.name=N'$CollectorLogin'
) ALTER ROLE dhc_collector ADD MEMBER [$CollectorLogin];
"@
 Write-Host 'Repository installation complete. No existing history removed.' -ForegroundColor Green
}finally{$conn.Dispose()}
