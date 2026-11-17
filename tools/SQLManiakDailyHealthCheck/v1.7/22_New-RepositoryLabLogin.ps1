#requires -Version 7.2
<#
.SYNOPSIS
  Test 31: provision a dedicated least-privilege SQL login on Docker LAB Repository.
.DESCRIPTION
  Generates an unpredictable SQL password in memory, creates only the LAB
  login/user and adds it to the existing dhc_collector database role.
  Requires admin connection to 127.0.0.1,15433/SQLManiakHealthHistory.
  Run: $labRepoCredential = .\22_New-RepositoryLabLogin.ps1 -RepositoryConnectionString $builder.ConnectionString
  This command returns one PSCredential; no password is written to Git or a file.
  Refuses to overwrite existing login/user, and does not reset passwords.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$RepositoryConnectionString
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module SqlServer -ErrorAction Stop
Add-Type -AssemblyName Microsoft.Data.SqlClient -ErrorAction Stop

$loginName='dhc_repository_collector_lab'
$builder=[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new($RepositoryConnectionString)
if([string]$builder['Data Source'] -ne '127.0.0.1,15433' -or
   [string]$builder['Initial Catalog'] -ne 'SQLManiakHealthHistory') {
 throw 'Test 31 is permitted only for Docker LAB Repository 127.0.0.1,15433/SQLManiakHealthHistory.'
}
$checkConnection=[Microsoft.Data.SqlClient.SqlConnection]::new($RepositoryConnectionString)
try {
 $checkConnection.Open()
 $check=$checkConnection.CreateCommand()
 try {
  $check.CommandText=@'
SELECT
 CASE WHEN DATABASE_PRINCIPAL_ID(N'dhc_collector') IS NULL THEN 0 ELSE 1 END AS RolePresent,
 CASE WHEN DATABASE_PRINCIPAL_ID(N'dhc_repository_collector_lab') IS NULL THEN 0 ELSE 1 END AS UserPresent,
 CASE WHEN EXISTS(SELECT 1 FROM sys.server_principals WHERE name=N'dhc_repository_collector_lab')
      THEN 1 ELSE 0 END AS LoginPresent;
'@
  $rd=$check.ExecuteReader()
  try {
   if(-not $rd.Read()) {throw 'Repository preflight returned no row.'}
   if($rd.GetInt32(0) -ne 1) {throw 'Missing dhc_collector role; run 20_RepositoryLeastPrivilege.sql.'}
   if($rd.GetInt32(1) -ne 0 -or $rd.GetInt32(2) -ne 0) {
    throw 'Dedicated LAB login or user already exists: refusing to alter or reset it.'
   }
  } finally {$rd.Dispose()}
 } finally {$check.Dispose()}
} finally {$checkConnection.Dispose()}

# Cryptographic bytes + explicit complexity suffix, not Random/Guid entropy.
$secretBytes=[Security.Cryptography.RandomNumberGenerator]::GetBytes(48)
try {
 $plain=[Convert]::ToBase64String($secretBytes)+'!aA9'
 $secure=ConvertTo-SecureString -String $plain -AsPlainText -Force
 $credential=[PSCredential]::new($loginName,$secure)
 # Password is generated internally, never accepted from file/chat.
 # Only base64 characters + explicit complexity suffix are present.
 $adminConn=[Microsoft.Data.SqlClient.SqlConnection]::new($RepositoryConnectionString)
 try {
  $adminConn.Open()
  $cmd=$adminConn.CreateCommand()
  try {
   $cmd.CommandTimeout=30
   $cmd.CommandText="CREATE LOGIN [$loginName] WITH PASSWORD=N'$plain', CHECK_POLICY=ON, CHECK_EXPIRATION=OFF, DEFAULT_DATABASE=[SQLManiakHealthHistory];"
   [void]$cmd.ExecuteNonQuery()
  } finally {$cmd.Dispose()}
  $userCmd=$adminConn.CreateCommand()
  try {
   $userCmd.CommandTimeout=30
   $userCmd.CommandText=@'
CREATE USER [dhc_repository_collector_lab] FOR LOGIN [dhc_repository_collector_lab];
ALTER ROLE [dhc_collector] ADD MEMBER [dhc_repository_collector_lab];
'@
   [void]$userCmd.ExecuteNonQuery()
  } catch {
   Write-Warning 'Login may have been created but database user/role grant failed. Review manually; no automatic cleanup.'
   throw
  } finally {$userCmd.Dispose()}
 } finally {$adminConn.Dispose()}
 Write-Host "Created dedicated LAB repository login $loginName; assigned only dhc_collector." -ForegroundColor Green
 Write-Host 'Capture returned PSCredential and export immediately to a NEW DPAPI folder.'
 return $credential
}
finally {
 if($null -ne $secretBytes){[Array]::Clear($secretBytes,0,$secretBytes.Length)}
 $plain=$null
}
