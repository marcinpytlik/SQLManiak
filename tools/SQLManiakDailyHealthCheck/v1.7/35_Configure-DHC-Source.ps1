#requires -Version 7.2
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$ServerInstance,
 [Parameter(Mandatory)][PSCredential]$AdministratorCredential,
 [Parameter(Mandatory)][string]$CollectorLogin,
 [PSCredential]$NewCollectorCredential,
 [switch]$TrustServerCertificate,
 [switch]$Apply,
 [switch]$GrantAlterTrace
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

# Source configuration: least privilege, optional broad trace permission.
if(-not $Apply){
 Write-Host "PREVIEW: SQL Server $ServerInstance; source login $CollectorLogin; VIEW SERVER PERFORMANCE STATE, VIEW SERVER SECURITY STATE, VIEW ANY ERROR LOG, VIEW ANY DEFINITION, msdb Agent reader; ALTER TRACE=$([bool]$GrantAlterTrace)."
 return
}
$conn=Open-Connection 'master'
try {
 if([int]($conn.ServerVersion.Split('.')[0]) -lt 16){throw 'SQL Server 2022+ required; 2016/2019 need separate permission model.'}
 Ensure-Login $conn
 Exec-Sql $conn @"
GRANT VIEW SERVER PERFORMANCE STATE TO [$CollectorLogin];
GRANT VIEW SERVER SECURITY STATE TO [$CollectorLogin];
GRANT VIEW ANY ERROR LOG TO [$CollectorLogin];
GRANT VIEW ANY DEFINITION TO [$CollectorLogin];
"@
 if($GrantAlterTrace){
  Write-Warning 'ALTER TRACE is broad: grants trace management. Requires explicit security review.'
  Exec-Sql $conn @"
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name=N'dhc_autogrowth_reader' AND type<>'R')
 THROW 51303,'Incompatible existing server principal dhc_autogrowth_reader',1;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name=N'dhc_autogrowth_reader')
 CREATE SERVER ROLE dhc_autogrowth_reader AUTHORIZATION [sa];
GRANT ALTER TRACE TO dhc_autogrowth_reader;
IF NOT EXISTS (
 SELECT 1 FROM sys.server_role_members m
 JOIN sys.server_principals r ON r.principal_id=m.role_principal_id
 JOIN sys.server_principals u ON u.principal_id=m.member_principal_id
 WHERE r.name=N'dhc_autogrowth_reader' AND u.name=N'$CollectorLogin'
) ALTER SERVER ROLE dhc_autogrowth_reader ADD MEMBER [$CollectorLogin];
"@
 }
}finally{$conn.Dispose()}
$conn=Open-Connection 'msdb'
try {
 Exec-Sql $conn @"
IF DATABASE_PRINCIPAL_ID(N'$CollectorLogin') IS NULL CREATE USER [$CollectorLogin] FOR LOGIN [$CollectorLogin];
IF NOT EXISTS (
 SELECT 1 FROM sys.database_role_members m
 JOIN sys.database_principals r ON r.principal_id=m.role_principal_id
 JOIN sys.database_principals u ON u.principal_id=m.member_principal_id
 WHERE r.name=N'SQLAgentReaderRole' AND u.name=N'$CollectorLogin'
) ALTER ROLE SQLAgentReaderRole ADD MEMBER [$CollectorLogin];
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name=N'dhc_agent_history_reader' AND type<>'R')
 THROW 51312,'Incompatible msdb principal dhc_agent_history_reader',1;
IF DATABASE_PRINCIPAL_ID(N'dhc_agent_history_reader') IS NULL
 CREATE ROLE dhc_agent_history_reader AUTHORIZATION dbo;
GRANT SELECT ON OBJECT::dbo.sysjobschedules TO dhc_agent_history_reader;
GRANT SELECT ON OBJECT::dbo.sysjobhistory TO dhc_agent_history_reader;
GRANT SELECT ON OBJECT::dbo.sysjobs TO dhc_agent_history_reader;
GRANT SELECT ON OBJECT::dbo.sysjobactivity TO dhc_agent_history_reader;
GRANT SELECT ON OBJECT::dbo.sysschedules TO dhc_agent_history_reader;
GRANT EXECUTE ON OBJECT::dbo.agent_datetime TO dhc_agent_history_reader;
IF NOT EXISTS (
 SELECT 1 FROM sys.database_role_members m
 JOIN sys.database_principals r ON r.principal_id=m.role_principal_id
 JOIN sys.database_principals u ON u.principal_id=m.member_principal_id
 WHERE r.name=N'dhc_agent_history_reader' AND u.name=N'$CollectorLogin'
) ALTER ROLE dhc_agent_history_reader ADD MEMBER [$CollectorLogin];
"@
 Write-Host 'Source grants complete. No sysadmin granted.' -ForegroundColor Green
}finally{$conn.Dispose()}
