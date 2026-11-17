#requires -Version 7.2
<#
.SYNOPSIS
  Test 32: independent effective permission check of dedicated LAB Repository login.
.DESCRIPTION
  Read-only. Connects as supplied SQL login, verifies required operations
  and confirms forbidden DELETE/ALTER/CONTROL, db_owner and sysadmin are absent.
  Does not run DHC or expose the password.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][PSCredential]$RepositoryCredential,
 [string]$RepositoryServer='127.0.0.1,15433'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Add-Type -AssemblyName Microsoft.Data.SqlClient -ErrorAction Stop
if($RepositoryServer -ne '127.0.0.1,15433' -or
   $RepositoryCredential.UserName -ne 'dhc_repository_collector_lab') {
 throw 'Only dedicated Docker LAB repository login is supported.'
}
$b=[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new()
$b['Data Source']=$RepositoryServer
$b['Initial Catalog']='SQLManiakHealthHistory'
$b['User ID']=$RepositoryCredential.UserName
$b['Password']=$RepositoryCredential.GetNetworkCredential().Password
$b['Encrypt']='True'
$b['Trust Server Certificate']=$true
$b['Persist Security Info']=$false
$conn=[Microsoft.Data.SqlClient.SqlConnection]::new($b.ConnectionString)
try {
 $conn.Open()
 $cmd=$conn.CreateCommand()
 try {
  $cmd.CommandText=@'
SELECT
 SUSER_SNAME() AS LoginName,
 DB_NAME() AS DbName,
 ISNULL(IS_SRVROLEMEMBER('sysadmin'),0) AS IsSysadmin,
 ISNULL(IS_ROLEMEMBER('db_owner'),0) AS IsDbOwner,
 ISNULL(IS_ROLEMEMBER('dhc_collector'),0) AS IsCollector,
 HAS_PERMS_BY_NAME('dhc.MonitoredServer','OBJECT','SELECT') AS CanReadInventory,
 HAS_PERMS_BY_NAME('dhc.ExecutionLog','OBJECT','SELECT') AS CanReadExecutionLog,
 HAS_PERMS_BY_NAME('dhc.ExecutionLog','OBJECT','INSERT') AS CanWriteExecutionLog,
 HAS_PERMS_BY_NAME('dhc.ExecutionLog','OBJECT','UPDATE') AS CanUpdateExecutionLog,
 HAS_PERMS_BY_NAME('dhc.TryStartExecution','OBJECT','EXECUTE') AS CanClaim,
 HAS_PERMS_BY_NAME('dhc.Run','OBJECT','INSERT') AS CanInsertRun,
 HAS_PERMS_BY_NAME('dhc.Run','OBJECT','UPDATE') AS CanUpdateRun,
 HAS_PERMS_BY_NAME('dhc.ResultBatch','OBJECT','INSERT') AS CanInsertBatch,
 HAS_PERMS_BY_NAME('dhc.Alert','OBJECT','INSERT') AS CanInsertAlert,
 HAS_PERMS_BY_NAME('dhc.TempDBSnapshot','OBJECT','INSERT') AS CanInsertSnapshot,
 HAS_PERMS_BY_NAME('dhc.TempDBFile','OBJECT','INSERT') AS CanInsertTempDBFile,
 HAS_PERMS_BY_NAME('dhc.TempDBSession','OBJECT','INSERT') AS CanInsertTempDBSession,
 HAS_PERMS_BY_NAME('dhc.Run','OBJECT','DELETE') AS CanDeleteRun,
 HAS_PERMS_BY_NAME('dhc.Run','OBJECT','ALTER') AS CanAlterRun,
 HAS_PERMS_BY_NAME('dhc.Run','OBJECT','CONTROL') AS CanControlRun;
'@
  $reader=$cmd.ExecuteReader()
  try {
   if(-not $reader.Read()) {throw 'Permission query returned no row.'}
   $cols=@{}
   for($i=0;$i -lt $reader.FieldCount;$i++){
    $cols[$reader.GetName($i)] = if($reader.IsDBNull($i)){$null}else{$reader.GetValue($i)}
   }
  } finally {$reader.Dispose()}
 } finally {$cmd.Dispose()}
 $required=@('IsCollector','CanReadInventory','CanReadExecutionLog',
  'CanWriteExecutionLog','CanUpdateExecutionLog','CanClaim','CanInsertRun',
  'CanUpdateRun','CanInsertBatch','CanInsertAlert','CanInsertSnapshot',
  'CanInsertTempDBFile','CanInsertTempDBSession')
 $denied=@('IsSysadmin','IsDbOwner','CanDeleteRun','CanAlterRun','CanControlRun')
 $errors=@()
 if($cols.LoginName -ne $RepositoryCredential.UserName -or
    $cols.DbName -ne 'SQLManiakHealthHistory') {$errors+='Unexpected SQL identity or database.'}
 foreach($name in $required){if($cols[$name] -ne 1){$errors+="Missing required permission: $name"}}
 foreach($name in $denied){if($cols[$name] -ne 0){$errors+="Forbidden permission present: $name"}}
 [pscustomobject]@{
  LoginName=$cols.LoginName
  Database=$cols.DbName
  RequiredGrantsPassed=($required.Count - ($errors | Where-Object {$_ -like 'Missing*'}).Count)
  RequiredGrantsTotal=$required.Count
  ProhibitedPrivilegesAbsent=($denied.Count - ($errors | Where-Object {$_ -like 'Forbidden*'}).Count)
  ProhibitedPrivilegesTotal=$denied.Count
  Verdict=if($errors.Count -eq 0){'PASS'}else{'FAIL'}
 }
 if($errors.Count -gt 0){throw "Test 32 FAILED: $($errors -join '; ')"}
 Write-Host 'Test 32: PASS. Dedicated SQL repository account has expected effective rights.' -ForegroundColor Green
}
finally {$conn.Dispose();$b.Clear()}
