#requires -Version 7.2
<#
.SYNOPSIS
  Test 36C: effective source-object permissions for dedicated Docker LAB logins.
.DESCRIPTION
  Read-only probes against 127.0.0.1,15434 and 127.0.0.1,15435.
  Tests real access (not only HAS_PERMS_BY_NAME), since system-object metadata
  can return NULL or differ from the runtime permission evaluation.
  Nothing is granted/created/modified. Does not alter Agent state.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][hashtable]$SourceCredentialByServer,
 [ValidateRange(1,300)][int]$ConnectionTimeout=5,
 [ValidateRange(1,300)][int]$QueryTimeout=30
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module SqlServer -ErrorAction Stop
Add-Type -AssemblyName Microsoft.Data.SqlClient -ErrorAction Stop

$targets=[ordered]@{
 '127.0.0.1,15434'='dhc_source_collector_lab_1'
 '127.0.0.1,15435'='dhc_source_collector_lab_2'
}
$probes=@(
 [pscustomobject]@{
  Test='ERRORLOG xp_readerrorlog'; Database='master'
  Query=@'
EXEC master.dbo.xp_readerrorlog 0, 1, N'__DHC36C_NO_MATCH_8C7798__';
'@
 },
 [pscustomobject]@{
  Test='msdb sysschedules'; Database='msdb'
  Query=@'
SELECT TOP (0) schedule_id FROM dbo.sysschedules;
'@
 },
 [pscustomobject]@{
  Test='msdb agent_datetime'; Database='msdb'
  Query=@'
SELECT dbo.agent_datetime(20261117, 120000) AS AgentDateTime;
'@
 }
)
$results=[System.Collections.Generic.List[object]]::new()

function Invoke-ReadOnlyProbe([Microsoft.Data.SqlClient.SqlConnection]$Connection,[string]$Query,[int]$Timeout) {
 $cmd=$Connection.CreateCommand()
 try {
  $cmd.CommandTimeout=$Timeout
  $cmd.CommandText=$Query
  $reader=$cmd.ExecuteReader()
  try {
   do {
    while($reader.Read()) { } # Drain any returned diagnostic rows.
   } while($reader.NextResult())
  } finally {$reader.Dispose()}
 } finally {$cmd.Dispose()}
}
foreach($target in $targets.Keys) {
 $expected=$targets[$target]
 if(-not $SourceCredentialByServer.ContainsKey($target) -or
    $SourceCredentialByServer[$target] -isnot [PSCredential]) {
  throw "Missing PSCredential for $target"
 }
 $cred=$SourceCredentialByServer[$target]
 if($cred.UserName -ne $expected) {throw "Wrong login for $target; expected $expected"}
 foreach($probe in $probes) {
  $builder=[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new()
  $builder['Data Source']=$target
  $builder['Initial Catalog']=$probe.Database
  $builder['User ID']=$cred.UserName
  $builder['Password']=$cred.GetNetworkCredential().Password
  $builder['Encrypt']='True'
  $builder['Trust Server Certificate']=$true
  $builder['Connect Timeout']=$ConnectionTimeout
  $builder['Persist Security Info']=$false
  $conn=[Microsoft.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
  $status='PASS'
  $message='Read-only statement executed.'
  try {
   $conn.Open()
   Invoke-ReadOnlyProbe -Connection $conn -Query $probe.Query -Timeout $QueryTimeout
  } catch {
   $status='FAIL'
   $message=$_.Exception.Message
  } finally {
   $conn.Dispose()
   $builder.Clear()
  }
  $results.Add([pscustomobject]@{
   ServerInstance=$target
   Login=$expected
   Check=$probe.Test
   Result=$status
   Details=$message
  })
 }
}
$results | Format-Table ServerInstance,Check,Result,Details -AutoSize -Wrap
$failed=@($results | Where-Object Result -ne 'PASS')
if($failed.Count -gt 0){
 Write-Warning "Test 36C: $($failed.Count) of $($results.Count) read-only probes FAILED."
 foreach($item in $failed){Write-Warning "$($item.ServerInstance) / $($item.Check): $($item.Details)"}
 throw 'Test 36C FAILED. Correct only the identified permissions before rerunning full collection.'
}
Write-Host "Test 36C: PASS ($($results.Count)/$($results.Count) real source-object probes)." -ForegroundColor Green
