#requires -Version 7.2
<#
 Test 36: creates separate DPAPI config with dedicated repository + source
 credentials, checks preview, then invokes existing Test 28 harness to force
 target1 DUE and target2 NOT_DUE. Also checks source permissions/alerts.
 No changes to v2 or leastpriv folders. No Agent job enabled.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$AdminRepositoryConnectionString,
 [Parameter(Mandatory)][PSCredential]$RepositoryCredential,
 [Parameter(Mandatory)][hashtable]$SourceCredentialByServer,
 [string]$SecretsDirectory=(Join-Path $env:LOCALAPPDATA 'SQLManiakDHC-fullleastpriv')
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module SqlServer -ErrorAction Stop
Add-Type -AssemblyName Microsoft.Data.SqlClient -ErrorAction Stop
$targets=@('127.0.0.1,15434','127.0.0.1,15435')
if($RepositoryCredential.UserName -ne 'dhc_repository_collector_lab'){throw 'Unexpected repository identity.'}
foreach($target in $targets){
 if(-not $SourceCredentialByServer.ContainsKey($target)){throw "Source credential missing: $target"}
 $c=$SourceCredentialByServer[$target]
 $expected=if($target.EndsWith('15434')){'dhc_source_collector_lab_1'}else{'dhc_source_collector_lab_2'}
 if($c -isnot [PSCredential] -or $c.UserName -ne $expected){throw "Unexpected source credential identity for $target"}
}
$config=Join-Path $SecretsDirectory 'scheduler.json'
if(-not(Test-Path -LiteralPath $config -PathType Leaf)){
 & (Join-Path $PSScriptRoot '16_Save-DHC-SchedulerConfig.ps1') -RepositoryServer '127.0.0.1,15433' -RepositoryCredential $RepositoryCredential -SqlCredentialByServer $SourceCredentialByServer -SecretsDirectory $SecretsDirectory -TrustServerCertificate
}
Write-Host 'PREVIEW with dedicated repository identity and dedicated source credentials.'
& (Join-Path $PSScriptRoot '17_Invoke-DHC-Scheduled.ps1') -ConfigPath $config -Environment LAB
# Direct source checks to detect inappropriate elevated privileges.
foreach($target in $targets){
 $c=$SourceCredentialByServer[$target]
 $b=[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new()
 $b['Data Source']=$target
 $b['Initial Catalog']='master'
 $b['User ID']=$c.UserName
 $b['Password']=$c.GetNetworkCredential().Password
 $b['Encrypt']='True'
 $b['Trust Server Certificate']=$true
 $conn=[Microsoft.Data.SqlClient.SqlConnection]::new($b.ConnectionString)
 try {
  $conn.Open()
  $cmd=$conn.CreateCommand()
  try {
   $cmd.CommandText=@'
SELECT
 SUSER_SNAME() AS LoginName,
 ISNULL(IS_SRVROLEMEMBER('sysadmin'),0) AS IsSysadmin,
 HAS_PERMS_BY_NAME(NULL,NULL,'VIEW SERVER PERFORMANCE STATE') AS CanPerf,
 HAS_PERMS_BY_NAME(NULL,NULL,'VIEW SERVER SECURITY STATE') AS CanSecurity,
 HAS_PERMS_BY_NAME(NULL,NULL,'VIEW ANY ERROR LOG') AS CanErrorLog;
'@
   $r=$cmd.ExecuteReader()
   try {
    if(-not $r.Read()){throw 'Source permission query returned zero rows.'}
    if($r.GetInt32(1) -ne 0 -or $r.GetInt32(2) -ne 1 -or $r.GetInt32(3) -ne 1 -or $r.GetInt32(4) -ne 1){
     throw "Source effective rights unexpected: $target"
    }
   } finally {$r.Dispose()}
  } finally {$cmd.Dispose()}
 } finally {$conn.Dispose();$b.Clear()}
 Write-Host "Source privileges $target : PASS (no sysadmin)." -ForegroundColor Green
}
Write-Host 'EXECUTING LAB test harness with full least-privilege DPAPI config.' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot '19_Test-Scheduler-Due.ps1') -RepositoryConnectionString $AdminRepositoryConnectionString -ConfigPath $config -ConnectionTimeout 3 -QueryTimeout 30

# Scan last completed source run for hidden permission error captured as warning.
$b=[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new($AdminRepositoryConnectionString)
if([string]$b['Data Source'] -ne '127.0.0.1,15433' -or [string]$b['Initial Catalog'] -ne 'SQLManiakHealthHistory'){
 throw 'Unexpected LAB repository admin connection.'
}
$conn=[Microsoft.Data.SqlClient.SqlConnection]::new($AdminRepositoryConnectionString)
try {
 $conn.Open()
 $cmd=$conn.CreateCommand()
 try {
  $cmd.CommandText=@'
SELECT TOP (1) r.RunId,r.Status
FROM dhc.Run AS r
WHERE r.ServerInstance=N'127.0.0.1,15434'
ORDER BY r.StartedUTC DESC;
'@
  $r=$cmd.ExecuteReader()
  try {
   if(-not $r.Read()){throw 'No source Run available.'}
   $runId=$r.GetGuid(0)
   if($r.GetString(1) -ne 'COMPLETE'){throw 'Latest Run was not COMPLETE.'}
  } finally {$r.Dispose()}
 } finally {$cmd.Dispose()}
 $audit=$conn.CreateCommand()
 try {
  $audit.CommandText=@'
SELECT COUNT_BIG(*) FROM dhc.Alert
WHERE RunId=@RunId
 AND (
   Details LIKE N'%permission%denied%'
   OR Details LIKE N'%permission%required%'
   OR Details LIKE N'%EXECUTE permission%'
   OR Details LIKE N'%SELECT permission%'
   OR Details LIKE N'%VIEW SERVER%'
   OR Details LIKE N'%not authorized%'
   OR Details LIKE N'%brak uprawnie%'
 );
'@
  $audit.Parameters.Add('@RunId',[System.Data.SqlDbType]::UniqueIdentifier).Value=$runId
  $denied=[long]$audit.ExecuteScalar()
  if($denied -gt 0){throw "Test 36 FAIL: $denied alert(s) indicate denied permissions. Inspect dhc.Alert for RunId $runId"}
  Write-Host "Test 36: PASS (new COMPLETE; no recognized permission-denied alerts). RunId=$runId" -ForegroundColor Green
 } finally {$audit.Dispose()}
} finally {$conn.Dispose()}
Write-Warning 'Only target 15434 was forced to DUE. Target 15435 source collection with new identity still needs a separate due-aware validation.'
