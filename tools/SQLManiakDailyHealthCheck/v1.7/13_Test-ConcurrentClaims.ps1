#requires -Version 7.2
<#
.SYNOPSIS
  Deterministic concurrency test for dhc.TryStartExecution.
.DESCRIPTION
  Creates a unique synthetic LAB inventory entry, starts claim A inside an
  outer transaction and holds the per-server applock, then starts claim B
  asynchronously on a separate connection. After a brief blocked interval,
  A commits; B must return RUNNING, not CLAIMED.
  Finally deletes only the synthetic execution and inventory entry.
  Run ONLY on a LAB repository with privileges to insert/delete test data.
  Does not contact any monitored SQL instance or run DHC.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$RepositoryConnectionString,
  [ValidateRange(100,5000)][int]$HoldMilliseconds = 750
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Add-Type -AssemblyName Microsoft.Data.SqlClient -ErrorAction Stop

function Open-Repo {
  $c=[Microsoft.Data.SqlClient.SqlConnection]::new($RepositoryConnectionString)
  try {
    $c.Open()
    if($c.Database -ne 'SQLManiakHealthHistory') {
      throw "Expected SQLManiakHealthHistory; connected to $($c.Database)."
    }
    return $c
  }
  catch { $c.Dispose(); throw }
}
function New-Command($Connection,[string]$Sql,$Transaction=$null) {
  $cmd=$Connection.CreateCommand()
  $cmd.CommandText=$Sql
  $cmd.CommandTimeout=30
  if($null -ne $Transaction) { $cmd.Transaction=$Transaction }
  return $cmd
}
function Add-Param($Cmd,[string]$Name,[System.Data.SqlDbType]$Type,$Value,[int]$Size=0) {
  $p=if($Size -gt 0){$Cmd.Parameters.Add($Name,$Type,$Size)}
      else{$Cmd.Parameters.Add($Name,$Type)}
  $p.Value=$Value
}
function New-ClaimCommand($Connection,[int]$Id,[guid]$ExecutionId,$Transaction=$null) {
  $cmd=New-Command $Connection 'dhc.TryStartExecution' $Transaction
  $cmd.CommandType=[System.Data.CommandType]::StoredProcedure
  Add-Param $cmd '@ServerId' ([System.Data.SqlDbType]::Int) $Id
  Add-Param $cmd '@ExecutionId' ([System.Data.SqlDbType]::UniqueIdentifier) $ExecutionId
  Add-Param $cmd '@Force' ([System.Data.SqlDbType]::Bit) $true
  return $cmd
}
function Read-Decision($Reader) {
  try {
    if(-not $Reader.Read()) {throw 'Claim returned no decision.'}
    return [string]$Reader.GetString(0)
  }
  finally {$Reader.Dispose()}
}

$tag=[guid]::NewGuid().ToString('N')
$name="DHC_TEST_CONCURRENT_$tag"
$cSetup=$null;$cA=$null;$cB=$null
$txA=$null;$cmdB=$null;$asyncB=$null
$serverId=$null
$testPassed=$false
try {
  $cSetup=Open-Repo
  $setup=New-Command $cSetup @'
INSERT dhc.MonitoredServer
(ServerInstance,DisplayName,Environment,MonitorGroup,
 IsEnabled,IntervalMinutes,CollectTempDB)
OUTPUT INSERTED.ServerId
VALUES (@Name,N'Concurrency test only','LAB',N'DHC_TEST',1,60,0);
'@
  try {
    Add-Param $setup '@Name' ([System.Data.SqlDbType]::NVarChar) $name 256
    $serverId=[int]$setup.ExecuteScalar()
  }
  finally {$setup.Dispose()}
  Write-Host "Created synthetic ServerId=$serverId (only)." -ForegroundColor Cyan

  $cA=Open-Repo
  $cB=Open-Repo
  $txA=$cA.BeginTransaction()
  $idA=[guid]::NewGuid()
  $idB=[guid]::NewGuid()

  $cmdA=New-ClaimCommand $cA $serverId $idA $txA
  try {
    $decisionA=Read-Decision ($cmdA.ExecuteReader())
  }
  finally {$cmdA.Dispose()}
  if($decisionA -ne 'CLAIMED') {
    throw "Claim A should be CLAIMED; actual=$decisionA"
  }
  Write-Host 'Claim A: CLAIMED (outer transaction remains open).' -ForegroundColor Cyan

  $cmdB=New-ClaimCommand $cB $serverId $idB
  $asyncB=$cmdB.BeginExecuteReader()

  # A still owns the transaction-scoped app lock. B must be waiting.
  $blocked= -not $asyncB.AsyncWaitHandle.WaitOne($HoldMilliseconds)
  if(-not $blocked) {
    # Consume the response before throwing to avoid leaving work pending.
    $early=Read-Decision ($cmdB.EndExecuteReader($asyncB))
    $asyncB=$null
    throw "Claim B completed while A still held the lock: $early"
  }
  Write-Host "Claim B: BLOCKED for at least $HoldMilliseconds ms." -ForegroundColor Cyan

  $txA.Commit()
  $txA.Dispose()
  $txA=$null
  $decisionB=Read-Decision ($cmdB.EndExecuteReader($asyncB))
  $asyncB=$null
  if($decisionB -ne 'RUNNING') {
    throw "Claim B should be RUNNING after A commit; actual=$decisionB"
  }
  Write-Host 'Claim B: RUNNING (duplicate claim rejected).' -ForegroundColor Green

  $check=New-Command $cSetup @'
SELECT COUNT_BIG(*)
FROM dhc.ExecutionLog
WHERE ServerId=@Id AND Status='RUNNING' AND ExecutionId=@ExecutionId;
'@
  try {
    Add-Param $check '@Id' ([System.Data.SqlDbType]::Int) $serverId
    Add-Param $check '@ExecutionId' ([System.Data.SqlDbType]::UniqueIdentifier) $idA
    $rows=[long]$check.ExecuteScalar()
  }
  finally {$check.Dispose()}
  if($rows -ne 1) {throw "Expected exactly one claimed execution A; found $rows."}
  $testPassed=$true
  [pscustomobject]@{
    Scenario='CONCURRENT_CLAIM'
    ServerId=$serverId
    FirstDecision=$decisionA
    SecondDecision=$decisionB
    BlockedBeforeCommit=$blocked
    ClaimedExecutionCount=$rows
    Verdict='PASS'
  }
}
finally {
  if($null -ne $txA) {
    try {$txA.Rollback()} catch {Write-Warning "Rollback A failed: $($_.Exception.Message)"}
    $txA.Dispose()
  }
  if($null -ne $cmdB) {$cmdB.Dispose()}
  if($null -ne $cA) {$cA.Dispose()}
  if($null -ne $cB) {$cB.Dispose()}
  if($null -ne $cSetup) {
    if($null -ne $serverId) {
      try {
        $clean=New-Command $cSetup @'
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DELETE dhc.ExecutionLog WHERE ServerId=@Id;
DELETE dhc.MonitoredServer WHERE ServerId=@Id;
COMMIT TRANSACTION;
'@
        try {
          Add-Param $clean '@Id' ([System.Data.SqlDbType]::Int) $serverId
          [void]$clean.ExecuteNonQuery()
          Write-Host 'Synthetic history and inventory entry removed.' -ForegroundColor Green
        }
        finally {$clean.Dispose()}
      }
      catch {Write-Warning "Cleanup failed for synthetic ServerId=$serverId; delete only this test entry manually: $($_.Exception.Message)"}
    }
    $cSetup.Dispose()
  }
}
