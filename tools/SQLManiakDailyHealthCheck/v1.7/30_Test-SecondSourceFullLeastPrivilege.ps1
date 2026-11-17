#requires -Version 7.2
<#
.SYNOPSIS
  Test 37: full dedicated-source collection on second LAB target (15435).
.DESCRIPTION
  Temporarily sets IntervalMinutes=1 ONLY on 127.0.0.1,15435.
  Invokes DPAPI scheduled wrapper and verifies one new COMPLETE on target 15435,
  with no new attempt on target 15434.
  Restores original interval in finally, including failures. Not for PROD.
  Requires existing full least-privilege LAB DPAPI config and admin repository connection.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$AdminRepositoryConnectionString,
 [string]$ConfigPath=(Join-Path $env:LOCALAPPDATA 'SQLManiakDHC-fullleastpriv\scheduler.json'),
 [ValidateRange(1,300)][int]$ConnectionTimeout=3,
 [ValidateRange(1,3600)][int]$QueryTimeout=30
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module SqlServer -ErrorAction Stop
Add-Type -AssemblyName Microsoft.Data.SqlClient -ErrorAction Stop

$target1='127.0.0.1,15435'
$target2='127.0.0.1,15434'
$repo=[Microsoft.Data.SqlClient.SqlConnection]::new($AdminRepositoryConnectionString)
$originalInterval=$null
$changed=$false
$verified=$false

function Invoke-RepoScalar([string]$Sql,[object]$Value=$null) {
 $cmd=$repo.CreateCommand()
 try {
  $cmd.CommandTimeout=30
  $cmd.CommandText=$Sql
  if($null -ne $Value) {
   $p=$cmd.Parameters.Add('@Instance',[System.Data.SqlDbType]::NVarChar,256)
   $p.Value=[string]$Value
  }
  return $cmd.ExecuteScalar()
 }
 finally {$cmd.Dispose()}
}
function Get-Count([string]$instance) {
 return [long](Invoke-RepoScalar @'
SELECT COUNT_BIG(*) FROM dhc.ExecutionLog WHERE ServerInstance=@Instance;
'@ $instance)
}
try {
 $repo.Open()
 if($repo.Database -ne 'SQLManiakHealthHistory') {throw 'Connect only to LAB SQLManiakHealthHistory repository.'}
 if(-not(Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {throw "Missing DPAPI config: $ConfigPath"}
 $config=Get-Content -LiteralPath $ConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
 if($config.RepositoryServer -ne '127.0.0.1,15433' -or $config.Version -ne 1) {
  throw 'This test is restricted to Docker LAB repository at 127.0.0.1,15433.'
 }
 $check=$repo.CreateCommand()
 try {
  $check.CommandText=@'
SELECT COUNT(*)
FROM dhc.MonitoredServer
WHERE Environment='LAB' AND IsEnabled=1 AND ServerInstance IN
 (N'127.0.0.1,15434',N'127.0.0.1,15435');
'@
  if([int]$check.ExecuteScalar() -ne 2) {throw 'Expected exactly two enabled Docker LAB targets.'}
 }
 finally {$check.Dispose()}

 # Verify the OTHER target will remain NOT_DUE BEFORE modifying anything.
 $check=$repo.CreateCommand()
 try {
  $check.CommandText=@'
SELECT CASE WHEN e.Status='RUNNING' THEN 'RUNNING'
            WHEN e.StartedUTC IS NULL THEN 'DUE'
            WHEN DATEADD(MINUTE,s.IntervalMinutes,e.StartedUTC)<=SYSUTCDATETIME() THEN 'DUE'
            ELSE 'NOT_DUE' END
FROM dhc.MonitoredServer s
OUTER APPLY (
 SELECT TOP(1) Status,StartedUTC
 FROM dhc.ExecutionLog e WHERE e.ServerInstance=s.ServerInstance
 ORDER BY e.StartedUTC DESC,e.ExecutionId DESC
) e
WHERE s.Environment='LAB' AND s.ServerInstance=N'127.0.0.1,15434';
'@
  $otherDue=[string]$check.ExecuteScalar()
  if($otherDue -ne 'NOT_DUE') {throw "Target 15434 is $otherDue; aborting to avoid unintended collection on 15434."}
 }
 finally {$check.Dispose()}

 $originalInterval=[int](Invoke-RepoScalar @'
SELECT IntervalMinutes FROM dhc.MonitoredServer
WHERE Environment='LAB' AND IsEnabled=1 AND ServerInstance=@Instance;
'@ $target1)
 if($originalInterval -ne 1440) {
  throw "Expected baseline IntervalMinutes=1440 on target 15435; found $originalInterval. Aborting."
 }
 $before1=Get-Count $target1
 $before2=Get-Count $target2
 $beforeRunId=[string](Invoke-RepoScalar @'
SELECT TOP (1) CONVERT(nvarchar(36),RunId) FROM dhc.Run
WHERE ServerInstance=@Instance ORDER BY StartedUTC DESC,RunId DESC;
'@ $target1)

 # Optimistic concurrency: only change if still at known baseline.
 $cmd=$repo.CreateCommand()
 try {
  $cmd.CommandText=@'
UPDATE dhc.MonitoredServer
SET IntervalMinutes=1
WHERE ServerInstance=@Instance AND Environment='LAB'
 AND IsEnabled=1 AND IntervalMinutes=1440;
SELECT @@ROWCOUNT;
'@
  $cmd.Parameters.Add('@Instance',[System.Data.SqlDbType]::NVarChar,256).Value=$target1
  if([int]$cmd.ExecuteScalar() -ne 1){throw 'Could not atomically change target 15435 IntervalMinutes.'}
  $changed=$true
 }
 finally {$cmd.Dispose()}
 Write-Host 'LAB target 15435 IntervalMinutes: 1440 -> 1 (temporary).' -ForegroundColor Cyan

 $wrapper=Join-Path $PSScriptRoot '17_Invoke-DHC-Scheduled.ps1'
 $results=@(& $wrapper -ConfigPath $ConfigPath -Environment LAB -Execute -ConnectionTimeout $ConnectionTimeout -QueryTimeout $QueryTimeout)
 $first=@($results | Where-Object {$_.ServerInstance -eq $target1})
 $second=@($results | Where-Object {$_.ServerInstance -eq $target2})
 if($first.Count -ne 1 -or $second.Count -ne 1) {
  throw 'Expected exactly one runner result per Docker target.'
 }
 $after1=Get-Count $target1
 $after2=Get-Count $target2
 $v1=($first[0].Status -eq 'COMPLETE' -and $after1 -eq ($before1+1))
 $v2=($second[0].Status -eq 'SKIPPED' -and $second[0].Error -eq 'NOT_DUE' -and $after2 -eq $before2)
 $verified=($v1 -and $v2)
 [pscustomobject]@{
  Target=$target1;Status=$first[0].Status;Before=$before1;After=$after1
  Verdict=if($v1){'PASS'}else{'FAIL'}
 }
 [pscustomobject]@{
  Target=$target2;Status=$second[0].Status;Before=$before2;After=$after2
  Verdict=if($v2){'PASS'}else{'FAIL'}
 }
 if(-not $verified){throw 'Test 37 scheduler assertions did not pass.'}
 Write-Host 'Test 37 scheduler: PASS (15435 COMPLETE and 15434 SKIPPED NOT_DUE).' -ForegroundColor Green
 $runCmd=$repo.CreateCommand()
 try {
  $runCmd.CommandText=@'
SELECT TOP (1) RunId,Status,SourceResultSets,SourceRowCount
FROM dhc.Run WHERE ServerInstance=@Instance
ORDER BY StartedUTC DESC,RunId DESC;
'@
  $runCmd.Parameters.Add('@Instance',[System.Data.SqlDbType]::NVarChar,256).Value=$target1
  $reader=$runCmd.ExecuteReader()
  try {
   if(-not $reader.Read()){throw 'No source dhc.Run for target 15435.'}
   $runId=$reader.GetGuid(0)
   $runStatus=$reader.GetString(1)
   $setCount=if($reader.IsDBNull(2)){$null}else{$reader.GetValue(2)}
   $rowCount=if($reader.IsDBNull(3)){$null}else{$reader.GetValue(3)}
  } finally {$reader.Dispose()}
 } finally {$runCmd.Dispose()}
 if($runStatus -ne 'COMPLETE' -or $runId.ToString() -eq $beforeRunId) {
  throw "Test 37 FAIL: expected a new COMPLETE Run; got RunId=$runId Status=$runStatus."
 }
 $audit=$repo.CreateCommand()
 try {
  $audit.CommandText=@'
SELECT COUNT_BIG(*) FROM dhc.Alert
WHERE RunId=@RunId AND (
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
 } finally {$audit.Dispose()}
 Write-Host "Target 15435 RunId=$runId; SourceResultSets=$setCount; SourceRowCount=$rowCount; PermissionDeniedAlerts=$denied"
 if($denied -gt 0) {throw "Test 37 FAIL: $denied permission-denied alert(s). Inspect dhc.Alert for RunId $runId"}
 Write-Host "Test 37: PASS (second source COMPLETE without recognized permission-denied alerts). RunId=$runId" -ForegroundColor Green
}
finally {
 if($changed) {
  try {
   $cmd=$repo.CreateCommand()
   try {
    $cmd.CommandText=@'
UPDATE dhc.MonitoredServer SET IntervalMinutes=@Original
WHERE ServerInstance=@Instance AND Environment='LAB' AND IntervalMinutes=1;
SELECT @@ROWCOUNT;
'@
    $cmd.Parameters.Add('@Instance',[System.Data.SqlDbType]::NVarChar,256).Value=$target1
    $cmd.Parameters.Add('@Original',[System.Data.SqlDbType]::Int).Value=$originalInterval
    if([int]$cmd.ExecuteScalar() -ne 1) {throw 'Restore did not affect exactly one row.'}
    Write-Host "RESTORED target 15435 IntervalMinutes=$originalInterval" -ForegroundColor Green
   } finally {$cmd.Dispose()}
  } catch {
   Write-Warning "CRITICAL: Could not restore LAB target 15435 interval. Restore manually in SQL! $($_.Exception.Message)"
   throw
  }
 }
 $repo.Dispose()
}
