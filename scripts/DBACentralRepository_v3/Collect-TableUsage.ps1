[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepositoryServerInstance,

    [string]$RepositoryDatabase = 'DBACentralRepository',

    [System.Management.Automation.PSCredential]$RepositorySqlCredential,

    [System.Management.Automation.PSCredential]$SourceSqlCredential,

    [int]$CommandTimeoutSeconds = 120,

    [long]$TableUsageTargetId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'modules\DBACentralRepository.Common\DBACentralRepository.Common.psd1'
Import-Module $modulePath -Force

function Invoke-RepoTable {
    param([string]$Sql,[hashtable]$Parameters=@{})
    Invoke-DBACentralDataTable -ServerInstance $RepositoryServerInstance -DatabaseName $RepositoryDatabase `
        -Sql $Sql -Credential $RepositorySqlCredential -Parameters $Parameters `
        -CommandTimeoutSeconds $CommandTimeoutSeconds -ApplicationName 'DBACentralRepository TableUsage Collector'
}

function Invoke-RepoNonQuery {
    param([string]$Sql,[hashtable]$Parameters=@{})
    [void](Invoke-DBACentralNonQuery -ServerInstance $RepositoryServerInstance -DatabaseName $RepositoryDatabase `
        -Sql $Sql -Credential $RepositorySqlCredential -Parameters $Parameters `
        -CommandTimeoutSeconds $CommandTimeoutSeconds -ApplicationName 'DBACentralRepository TableUsage Collector')
}

$targetSql = @'
SELECT
    T.TableUsageTargetId,
    T.InstanceId,
    I.ServerInstance,
    T.DatabaseName,
    T.AuditName,
    T.AuditPath,
    T.AuditReadOverlapMinutes
FROM perf.TableUsageTarget AS T
JOIN dbo.Instance AS I ON I.InstanceId=T.InstanceId
WHERE T.IsEnabled=1
'@
$targetParams = @{}
if ($TableUsageTargetId -gt 0) {
    $targetSql += ' AND T.TableUsageTargetId=@TableUsageTargetId'
    $targetParams.TableUsageTargetId = $TableUsageTargetId
}
$targetSql += ' ORDER BY I.ServerInstance,T.DatabaseName;'

$targets = Invoke-RepoTable -Sql $targetSql -Parameters $targetParams

foreach ($t in $targets.Rows) {
    $targetId = [long]$t.TableUsageTargetId
    $instanceId = [long]$t.InstanceId
    $serverInstance = [string]$t.ServerInstance
    $databaseName = [string]$t.DatabaseName
    $auditName = [string]$t.AuditName
    $auditPath = [string]$t.AuditPath
    $overlapMinutes = [int]$t.AuditReadOverlapMinutes
    $capturedAt = [DateTime]::UtcNow

    Write-Host "TABLE USAGE: $serverInstance / $databaseName" -ForegroundColor Cyan

    # ---------------------------------------------------------------------
    # 1. Exact cumulative table usage from sys.dm_db_index_usage_stats.
    # ---------------------------------------------------------------------
    $snapshotSql = @'
SELECT
    DB_ID() AS DatabaseId,
    DB_NAME() AS DatabaseName,
    T.object_id AS ObjectId,
    S.name AS SchemaName,
    T.name AS TableName,
    SUM(CONVERT(bigint,ISNULL(U.user_seeks,0))) AS UserSeeks,
    SUM(CONVERT(bigint,ISNULL(U.user_scans,0))) AS UserScans,
    SUM(CONVERT(bigint,ISNULL(U.user_lookups,0))) AS UserLookups,
    SUM(CONVERT(bigint,ISNULL(U.user_updates,0))) AS UserUpdates,
    MAX(U.last_user_seek) AS LastUserSeek,
    MAX(U.last_user_scan) AS LastUserScan,
    MAX(U.last_user_lookup) AS LastUserLookup,
    MAX(U.last_user_update) AS LastUserUpdate
FROM sys.tables AS T
JOIN sys.schemas AS S ON S.schema_id=T.schema_id
LEFT JOIN sys.indexes AS I
  ON I.object_id=T.object_id
 AND I.index_id >= 0
LEFT JOIN sys.dm_db_index_usage_stats AS U
  ON U.database_id=DB_ID()
 AND U.object_id=I.object_id
 AND U.index_id=I.index_id
WHERE T.is_ms_shipped=0
GROUP BY T.object_id,S.name,T.name;
'@

    $snapshot = Invoke-DBACentralDataTable -ServerInstance $serverInstance -DatabaseName $databaseName `
        -Sql $snapshotSql -Credential $SourceSqlCredential -Parameters @{} `
        -CommandTimeoutSeconds $CommandTimeoutSeconds -ApplicationName 'DBACentralRepository TableUsage Collector'

    [void]$snapshot.Columns.Add('TableUsageTargetId',[long])
    [void]$snapshot.Columns.Add('InstanceId',[long])
    [void]$snapshot.Columns.Add('CapturedAt',[datetime])
    foreach ($r in $snapshot.Rows) {
        $r.TableUsageTargetId=$targetId
        $r.InstanceId=$instanceId
        $r.CapturedAt=$capturedAt
    }

    if ($snapshot.Rows.Count -gt 0) {
        [void](Write-DBACentralBulkCopy -DataTable $snapshot -DestinationTable '[perf].[TableUsageSnapshot]' `
            -ServerInstance $RepositoryServerInstance -DatabaseName $RepositoryDatabase `
            -Credential $RepositorySqlCredential -CommandTimeoutSeconds $CommandTimeoutSeconds)
    }

    # ---------------------------------------------------------------------
    # 2. SQL Audit access data. Rebuild a short overlapping window so the
    #    import is idempotent and does not miss late-flushed audit records.
    # ---------------------------------------------------------------------
    if (-not ($auditPath.EndsWith('\') -or $auditPath.EndsWith('/'))) {
        $auditPath += '\'
    }
    $auditPattern = ($auditPath + $auditName + '_*.sqlaudit').Replace("'","''")
    $databaseLiteral = $databaseName.Replace("'","''")
    $qDatabase = '[' + $databaseName.Replace(']',']]') + ']'

    $majorVersion = [int](Invoke-DBACentralScalar -ServerInstance $serverInstance -DatabaseName 'master' `
        -Sql "SELECT CONVERT(int,SERVERPROPERTY('ProductMajorVersion'));" `
        -Credential $SourceSqlCredential -Parameters @{} -CommandTimeoutSeconds $CommandTimeoutSeconds `
        -ApplicationName 'DBACentralRepository TableUsage Collector')

    $lastBucket = Invoke-DBACentralScalar -ServerInstance $RepositoryServerInstance -DatabaseName $RepositoryDatabase `
        -Sql 'SELECT MAX(BucketStartUtc) FROM perf.TableAccessAggregate WHERE TableUsageTargetId=@TargetId;' `
        -Credential $RepositorySqlCredential -Parameters @{TargetId=$targetId} `
        -CommandTimeoutSeconds $CommandTimeoutSeconds -ApplicationName 'DBACentralRepository TableUsage Collector'

    if ($null -eq $lastBucket -or $lastBucket -is [DBNull]) {
        $fromUtc = [DateTime]::UtcNow.AddHours(-2)
    }
    else {
        $fromUtc = ([datetime]$lastBucket).AddMinutes(-1 * $overlapMinutes)
    }
    $toUtc = [DateTime]::UtcNow

    $appSelect = if ($majorVersion -ge 14) { 'application_name' } else { 'CAST(NULL AS nvarchar(128))' }
    $hostSelect = if ($majorVersion -ge 14) { 'host_name' } else { 'CAST(NULL AS nvarchar(128))' }

    $fromLiteral = $fromUtc.ToString('yyyy-MM-ddTHH:mm:ss')
    $toLiteral = $toUtc.ToString('yyyy-MM-ddTHH:mm:ss')

    $auditSql = @"
;WITH A AS
(
    SELECT
        event_time,
        succeeded,
        object_id,
        server_principal_name,
        session_server_principal_name,
        database_principal_name,
        database_name,
        schema_name,
        object_name,
        $appSelect AS application_name,
        $hostSelect AS host_name
    FROM sys.fn_get_audit_file(N'$auditPattern',DEFAULT,DEFAULT) AS F
    WHERE F.event_time >= CONVERT(datetime2(0),'$fromLiteral',126)
      AND F.event_time <  CONVERT(datetime2(0),'$toLiteral',126)
      AND F.database_name = N'$databaseLiteral'
      AND F.action_id = 'SL'
      AND F.sequence_number = 1
      AND F.object_name IS NOT NULL
      AND EXISTS (SELECT 1 FROM $qDatabase.sys.tables AS UT WHERE UT.object_id=F.object_id AND UT.is_ms_shipped=0)
)
SELECT
    DATEADD(minute,(DATEDIFF(minute,CONVERT(datetime2(0),'20000101',112),event_time)/5)*5,CONVERT(datetime2(0),'20000101',112)) AS BucketStartUtc,
    database_name AS DatabaseName,
    ISNULL(schema_name,N'') AS SchemaName,
    object_name AS ObjectName,
    NULLIF(object_id,0) AS ObjectId,
    server_principal_name AS ServerPrincipalName,
    session_server_principal_name AS SessionServerPrincipalName,
    database_principal_name AS DatabasePrincipalName,
    application_name AS ApplicationName,
    host_name AS HostName,
    COUNT_BIG(*) AS AccessCount,
    SUM(CONVERT(bigint,CASE WHEN succeeded=0 THEN 1 ELSE 0 END)) AS FailedCount
FROM A
GROUP BY
    DATEADD(minute,(DATEDIFF(minute,CONVERT(datetime2(0),'20000101',112),event_time)/5)*5,CONVERT(datetime2(0),'20000101',112)),
    database_name,schema_name,object_name,NULLIF(object_id,0),server_principal_name,
    session_server_principal_name,database_principal_name,application_name,host_name;
"@

    try {
        $access = Invoke-DBACentralDataTable -ServerInstance $serverInstance -DatabaseName 'master' `
            -Sql $auditSql -Credential $SourceSqlCredential -Parameters @{} `
            -CommandTimeoutSeconds $CommandTimeoutSeconds -ApplicationName 'DBACentralRepository TableUsage Collector'

        # Delete overlapping buckets and write refreshed aggregates.
        Invoke-RepoNonQuery -Sql @'
DELETE FROM perf.TableAccessAggregate
WHERE TableUsageTargetId=@TargetId
  AND BucketStartUtc>=@FromUtc
  AND BucketStartUtc<@ToUtc;
'@ -Parameters @{TargetId=$targetId;FromUtc=$fromUtc;ToUtc=$toUtc}

        [void]$access.Columns.Add('TableUsageTargetId',[long])
        [void]$access.Columns.Add('InstanceId',[long])
        foreach ($r in $access.Rows) {
            $r.TableUsageTargetId=$targetId
            $r.InstanceId=$instanceId
        }

        if ($access.Rows.Count -gt 0) {
            [void](Write-DBACentralBulkCopy -DataTable $access -DestinationTable '[perf].[TableAccessAggregate]' `
                -ServerInstance $RepositoryServerInstance -DatabaseName $RepositoryDatabase `
                -Credential $RepositorySqlCredential -CommandTimeoutSeconds $CommandTimeoutSeconds)
        }

        Write-Host "  snapshots=$($snapshot.Rows.Count), audit aggregates=$($access.Rows.Count)" -ForegroundColor Green
    }
    catch {
        Write-Warning (
    'Audit import failed for {0} / {1}: {2}' -f
    $serverInstance,
    $databaseName,
    $_.Exception.Message
)
        Write-Warning 'DMV snapshot was saved. Verify SQL Audit is enabled and SQL Server service can write/read AuditPath.'
    }
}