#requires -Version 7.2
<#
.SYNOPSIS
  Manually run SQLManiak DHC v1.7 for enabled inventory entries.
.DESCRIPTION
  Reads dhc.MonitoredServer from the repository and invokes the existing
  single-instance collector sequentially. Preview is the default:
  specify -Execute to actually connect to targets and collect.
  A failure on one target is reported and does not stop other targets.
  -Execute runs only due instances. -Force overrides interval, but not RUNNING.
  Call from a scheduler; this script does not install a job.
  Source credentials are supplied at invocation; no passwords in inventory.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepositoryConnectionString,
    [PSCredential]$SqlCredential,
    [hashtable]$SqlCredentialByServer,
    [ValidateSet('PROD','TEST','DEV','LAB','DR')][string]$Environment,
    [string]$ServerInstance,
    [switch]$Execute,
    [switch]$Force,
    [switch]$TrustServerCertificate,
    [int]$QueryTimeout = 300,
    [ValidateRange(1,300)][int]$ConnectionTimeout = 5,
    [ValidateRange(1,1000)][int]$JsonBatchRows = 100,
    [string]$SqlFile = (Join-Path $PSScriptRoot 'SQLManiak_Daily_Health_Check_v1_5_CSV.sql'),
    [string]$TempDBSqlFile = (Join-Path $PSScriptRoot '02_TempDB_Collect.sql')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName Microsoft.Data.SqlClient -ErrorAction Stop

if($Execute) {
    if(-not (Test-Path -LiteralPath $SqlFile -PathType Leaf)) { throw "Missing DHC SQL file: $SqlFile" }
    if(-not (Test-Path -LiteralPath $TempDBSqlFile -PathType Leaf)) { throw "Missing TempDB SQL file: $TempDBSqlFile" }
}
$collector = Join-Path $PSScriptRoot '03_Run-DHC-v1_7.ps1'
if(-not (Test-Path -LiteralPath $collector -PathType Leaf)) { throw "Missing collector: $collector" }

# Query inventory with parameterized filters. No user-supplied SQL text.
$instances = [System.Collections.Generic.List[object]]::new()
$conn = [Microsoft.Data.SqlClient.SqlConnection]::new($RepositoryConnectionString)
try {
    $conn.Open()
    if($conn.Database -ne 'SQLManiakHealthHistory') {
        throw "Connected to database '$($conn.Database)', expected SQLManiakHealthHistory."
    }
    $cmd = $conn.CreateCommand()
    try {
        $cmd.CommandTimeout = 30
        $cmd.CommandText = @'
SELECT s.ServerId,s.ServerInstance,s.DisplayName,s.Environment,s.MonitorGroup,
       s.IntervalMinutes,s.CollectTempDB,
       CASE
         WHEN lastRun.Status='RUNNING' THEN 'RUNNING'
         WHEN lastRun.StartedUTC IS NULL THEN 'DUE'
         WHEN DATEADD(MINUTE,s.IntervalMinutes,lastRun.StartedUTC)<=SYSUTCDATETIME() THEN 'DUE'
         ELSE 'NOT_DUE'
       END AS DueStatus
FROM dhc.MonitoredServer AS s
OUTER APPLY (
    SELECT TOP (1) e.StartedUTC,e.Status
    FROM dhc.ExecutionLog AS e
    WHERE e.ServerInstance=s.ServerInstance
    ORDER BY e.StartedUTC DESC,e.ExecutionId DESC
) AS lastRun
WHERE s.IsEnabled=1
  AND (@Environment IS NULL OR s.Environment=@Environment)
  AND (@ServerInstance IS NULL OR s.ServerInstance=@ServerInstance)
ORDER BY s.Environment,s.MonitorGroup,s.ServerInstance;
'@
        $p = $cmd.Parameters.Add('@Environment',[System.Data.SqlDbType]::VarChar,12)
        $p.Value = if($Environment){$Environment}else{[DBNull]::Value}
        $p = $cmd.Parameters.Add('@ServerInstance',[System.Data.SqlDbType]::NVarChar,256)
        $p.Value = if($ServerInstance){$ServerInstance}else{[DBNull]::Value}
        $reader = $cmd.ExecuteReader()
        try {
            while($reader.Read()) {
                $instances.Add([pscustomobject]@{
                    ServerId = $reader.GetInt32(0)
                    ServerInstance = $reader.GetString(1)
                    DisplayName = if($reader.IsDBNull(2)){$null}else{$reader.GetString(2)}
                    Environment = $reader.GetString(3)
                    MonitorGroup = if($reader.IsDBNull(4)){$null}else{$reader.GetString(4)}
                    IntervalMinutes = $reader.GetInt32(5)
                    CollectTempDB = $reader.GetBoolean(6)
                    DueStatus = $reader.GetString(7)
                })
            }
        } finally { $reader.Dispose() }
    } finally { $cmd.Dispose() }
} finally { $conn.Dispose() }

if($instances.Count -eq 0) {
    Write-Warning 'No enabled monitored instances matched the supplied filters.'
    return
}

if(-not $Execute) {
    Write-Host 'PREVIEW ONLY. Add -Execute to run collection.' -ForegroundColor Yellow
    $instances | Select-Object ServerId,ServerInstance,Environment,MonitorGroup,
        IntervalMinutes,CollectTempDB,DueStatus
    return
}


# The execution log uses separate autocommit writes: it survives a source
# connection failure or a rollback in the source collector.
function Write-ExecutionLog([string]$Sql,[hashtable]$Values) {
    $logConn = [Microsoft.Data.SqlClient.SqlConnection]::new($RepositoryConnectionString)
    try {
        $logConn.Open()
        $logCmd = $logConn.CreateCommand()
        try {
            $logCmd.CommandTimeout = 30
            $logCmd.CommandText = $Sql
            foreach($key in $Values.Keys) {
                $value = $Values[$key]
                if($null -eq $value) { $value = [DBNull]::Value }
                $null = $logCmd.Parameters.AddWithValue('@'+$key,$value)
            }
            $count = $logCmd.ExecuteNonQuery()
            if($count -ne 1) { throw "ExecutionLog write affected $count rows; expected one." }
        }
        finally { $logCmd.Dispose() }
    }
    finally { $logConn.Dispose() }
}

# Atomic claim in repository: locks a single ServerId, rechecks due,
# and commits a RUNNING attempt before the target is contacted.
function Request-ExecutionClaim([int]$Id,[guid]$ExecutionId,[bool]$ForceRun) {
    $claimConn=[Microsoft.Data.SqlClient.SqlConnection]::new($RepositoryConnectionString)
    try {
        $claimConn.Open()
        $claimCmd=$claimConn.CreateCommand()
        try {
            $claimCmd.CommandTimeout=30
            $claimCmd.CommandType=[System.Data.CommandType]::StoredProcedure
            $claimCmd.CommandText='dhc.TryStartExecution'
            [void]$claimCmd.Parameters.Add('@ServerId',[System.Data.SqlDbType]::Int)
            $claimCmd.Parameters['@ServerId'].Value=$Id
            [void]$claimCmd.Parameters.Add('@ExecutionId',[System.Data.SqlDbType]::UniqueIdentifier)
            $claimCmd.Parameters['@ExecutionId'].Value=$ExecutionId
            [void]$claimCmd.Parameters.Add('@Force',[System.Data.SqlDbType]::Bit)
            $claimCmd.Parameters['@Force'].Value=$ForceRun
            $reader=$claimCmd.ExecuteReader()
            try {
                if(-not $reader.Read()) { throw 'Claim procedure returned no decision.' }
                return [string]$reader.GetString(0)
            }
            finally { $reader.Dispose() }
        }
        finally { $claimCmd.Dispose() }
    }
    finally { $claimConn.Dispose() }
}

Write-Host "DHC v1.7: processing $($instances.Count) monitored instance(s) sequentially." -ForegroundColor Cyan
$results = [System.Collections.Generic.List[object]]::new()
foreach($item in $instances) {
    $started = [datetime]::UtcNow
    $executionId = [guid]::NewGuid()
    $logStarted = $false
    try {
        $decision=Request-ExecutionClaim $item.ServerId $executionId ([bool]$Force)
        if($decision -ne 'CLAIMED') {
            $results.Add([pscustomobject]@{
                ExecutionId=$null
                ServerId=$item.ServerId
                ServerInstance=$item.ServerInstance
                Environment=$item.Environment
                Status='SKIPPED'
                RunId=$null
                RowsStored=0
                DurationMs=0
                Error=$decision
            })
            continue
        }
        $logStarted = $true

        $invoke = @{
            ServerInstance = $item.ServerInstance
            RepositoryConnectionString = $RepositoryConnectionString
            SqlFile = $SqlFile
            QueryTimeout = $QueryTimeout
            ConnectionTimeout = $ConnectionTimeout
            JsonBatchRows = $JsonBatchRows
            TrustServerCertificate = [bool]$TrustServerCertificate
        }
        if($null -ne $SqlCredentialByServer) {
            # Explicit per-server map takes precedence; never fall back silently.
            if(-not $SqlCredentialByServer.ContainsKey($item.ServerInstance)) {
                throw "Missing credential mapping for $($item.ServerInstance)."
            }
            $selectedCredential = $SqlCredentialByServer[$item.ServerInstance]
            if($selectedCredential -isnot [PSCredential]) {
                throw "Invalid credential mapping for $($item.ServerInstance); expected PSCredential."
            }
            $invoke.SqlCredential = $selectedCredential
        }
        elseif($null -ne $SqlCredential) { $invoke.SqlCredential = $SqlCredential }
        if($item.CollectTempDB) { $invoke.TempDBSqlFile = $TempDBSqlFile }
        else { $invoke.SkipTempDB = $true }

        $run = & $collector @invoke
        if($null -eq $run) { throw 'Collector returned no run summary.' }
        $finalStatus = [string]$run.Status
        if($finalStatus -notin @('COMPLETE','PARTIAL')) {
            throw "Unexpected collector status: $finalStatus."
        }
        Write-ExecutionLog @'
UPDATE dhc.ExecutionLog
SET FinishedUTC = SYSUTCDATETIME(),
    Status = @Status,
    RunId = @RunId,
    RowsStored = @RowsStored,
    ErrorText = NULL
WHERE ExecutionId = @ExecutionId AND Status = 'RUNNING';
'@ @{
            ExecutionId = $executionId
            Status = $finalStatus
            RunId = [guid]$run.RunId
            RowsStored = [long]$run.RowsStored
        }
        $results.Add([pscustomobject]@{
            ExecutionId = $executionId
            ServerId = $item.ServerId
            ServerInstance = $item.ServerInstance
            Environment = $item.Environment
            Status = $finalStatus
            RunId = [string]$run.RunId
            RowsStored = [long]$run.RowsStored
            DurationMs = [int]([datetime]::UtcNow-$started).TotalMilliseconds
            Error = $null
        })
    }
    catch {
        $message = $_.Exception.Message
        Write-Warning ("DHC failed for {0}: {1}" -f $item.ServerInstance,$message)
        if($logStarted) {
            try {
                Write-ExecutionLog @'
UPDATE dhc.ExecutionLog
SET FinishedUTC = SYSUTCDATETIME(),
    Status = 'FAILED',
    RunId = NULL,
    RowsStored = 0,
    ErrorText = @ErrorText
WHERE ExecutionId = @ExecutionId AND Status = 'RUNNING';
'@ @{
                    ExecutionId = $executionId
                    ErrorText = $message.Substring(0,[Math]::Min(4000,$message.Length))
                }
            }
            catch {
                Write-Warning ("Failed to persist failure to ExecutionLog for {0}: {1}" -f $item.ServerInstance,$_.Exception.Message)
            }
        }
        else {
            Write-Warning ("ExecutionLog start record was not stored for {0}." -f $item.ServerInstance)
        }
        $results.Add([pscustomobject]@{
            ExecutionId = $executionId
            ServerId = $item.ServerId
            ServerInstance = $item.ServerInstance
            Environment = $item.Environment
            Status = 'FAILED'
            RunId = $null
            RowsStored = 0
            DurationMs = [int]([datetime]::UtcNow-$started).TotalMilliseconds
            Error = $message
        })
    }
}
$results | Select-Object ExecutionId,ServerId,ServerInstance,Environment,Status,RunId,RowsStored,DurationMs,Error
