#requires -Version 7.2
<#
.SYNOPSIS
  Test 28: one LAB instance DUE, another NOT_DUE, via DPAPI scheduler.
.DESCRIPTION
  Temporarily sets IntervalMinutes=1 ONLY on 127.0.0.1,15434.
  Invokes scheduled wrapper -Execute and verifies exactly one new COMPLETE
  attempt on target 1 and no new attempt on target 2.
  Restores original interval in finally, including failures. Not for PROD.
  Requires a working LAB DPAPI config from Test 25 and SQL repository login.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$RepositoryConnectionString,
 [Parameter(Mandatory)][string]$ConfigPath,
 [ValidateRange(1,300)][int]$ConnectionTimeout=3,
 [ValidateRange(1,3600)][int]$QueryTimeout=30
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module SqlServer -ErrorAction Stop
Add-Type -AssemblyName Microsoft.Data.SqlClient -ErrorAction Stop

$target1='127.0.0.1,15434'
$target2='127.0.0.1,15435'
$repo=[Microsoft.Data.SqlClient.SqlConnection]::new($RepositoryConnectionString)
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

 # Verify target 2 will remain NOT_DUE BEFORE modifying anything.
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
WHERE s.Environment='LAB' AND s.ServerInstance=N'127.0.0.1,15435';
'@
  $otherDue=[string]$check.ExecuteScalar()
  if($otherDue -ne 'NOT_DUE') {throw "Target 2 is $otherDue; aborting to avoid unintended second DHC."}
 }
 finally {$check.Dispose()}

 $originalInterval=[int](Invoke-RepoScalar @'
SELECT IntervalMinutes FROM dhc.MonitoredServer
WHERE Environment='LAB' AND IsEnabled=1 AND ServerInstance=@Instance;
'@ $target1)
 if($originalInterval -ne 1440) {
  throw "Expected baseline IntervalMinutes=1440 on target 1; found $originalInterval. Aborting."
 }
 $before1=Get-Count $target1
 $before2=Get-Count $target2

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
  if([int]$cmd.ExecuteScalar() -ne 1){throw 'Could not atomically change target 1 IntervalMinutes.'}
  $changed=$true
 }
 finally {$cmd.Dispose()}
 Write-Host 'LAB target 1 IntervalMinutes: 1440 -> 1 (temporary).' -ForegroundColor Cyan

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
 if(-not $verified){throw 'Test 28 assertions did not pass.'}
 Write-Host 'Test 28: PASS (one COMPLETE and one SKIPPED NOT_DUE).' -ForegroundColor Green
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
    Write-Host "RESTORED target 1 IntervalMinutes=$originalInterval" -ForegroundColor Green
   } finally {$cmd.Dispose()}
  } catch {
   Write-Warning "CRITICAL: Could not restore LAB target 1 interval. Restore manually in SQL! $($_.Exception.Message)"
   throw
  }
 }
 $repo.Dispose()
}
