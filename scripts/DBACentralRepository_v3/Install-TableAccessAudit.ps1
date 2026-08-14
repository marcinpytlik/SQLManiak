[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$RepositoryServerInstance,

    [string]$RepositoryDatabase = 'DBACentralRepository',

    [System.Management.Automation.PSCredential]$RepositorySqlCredential,

    [System.Management.Automation.PSCredential]$SourceSqlCredential,

    [long]$TableUsageTargetId,

    [int]$CommandTimeoutSeconds = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'modules\DBACentralRepository.Common\DBACentralRepository.Common.psd1'
Import-Module $modulePath -Force

$params = @{}
$sql = @'
SELECT
    T.TableUsageTargetId,
    T.InstanceId,
    I.ServerInstance,
    T.DatabaseName,
    T.AuditName,
    T.AuditSpecificationName,
    T.AuditPath
FROM perf.TableUsageTarget AS T
JOIN dbo.Instance AS I ON I.InstanceId=T.InstanceId
WHERE T.IsEnabled=1
'@
if ($TableUsageTargetId -gt 0) {
    $sql += ' AND T.TableUsageTargetId=@TableUsageTargetId'
    $params.TableUsageTargetId = $TableUsageTargetId
}
$sql += ' ORDER BY I.ServerInstance,T.DatabaseName;'

$targets = Invoke-DBACentralDataTable `
    -ServerInstance $RepositoryServerInstance `
    -DatabaseName $RepositoryDatabase `
    -Sql $sql `
    -Credential $RepositorySqlCredential `
    -Parameters $params `
    -CommandTimeoutSeconds $CommandTimeoutSeconds `
    -ApplicationName 'DBACentralRepository TableAccess Audit Installer'

foreach ($t in $targets.Rows) {
    $serverInstance = [string]$t.ServerInstance
    $databaseName = [string]$t.DatabaseName
    $auditName = [string]$t.AuditName
    $specName = [string]$t.AuditSpecificationName
    $auditPath = [string]$t.AuditPath

    if (-not ($auditPath.EndsWith('\') -or $auditPath.EndsWith('/'))) {
        $auditPath += '\'
    }

    if (-not $PSCmdlet.ShouldProcess("$serverInstance / $databaseName", 'Create or enable SQL Server Audit for table access')) {
        continue
    }

    $qAudit = '[' + $auditName.Replace(']',']]') + ']'
    $qSpec = '[' + $specName.Replace(']',']]') + ']'
    $qDb = '[' + $databaseName.Replace(']',']]') + ']'
    $pathLiteral = $auditPath.Replace("'", "''")
    $auditNameLiteral = $auditName.Replace("'", "''")
    $specNameLiteral = $specName.Replace("'", "''")

    $serverSql = @"
USE [master];
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name=N'$auditNameLiteral')
BEGIN
    CREATE SERVER AUDIT $qAudit
    TO FILE
    (
        FILEPATH = N'$pathLiteral',
        MAXSIZE = 1024 MB,
        MAX_ROLLOVER_FILES = 20,
        RESERVE_DISK_SPACE = OFF
    )
    WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);
END;
ALTER SERVER AUDIT $qAudit WITH (STATE = ON);
"@

    [void](Invoke-DBACentralNonQuery `
        -ServerInstance $serverInstance `
        -DatabaseName 'master' `
        -Sql $serverSql `
        -Credential $SourceSqlCredential `
        -CommandTimeoutSeconds $CommandTimeoutSeconds `
        -ApplicationName 'DBACentralRepository TableAccess Audit Installer')

    $dbSql = @"
USE $qDb;
IF NOT EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name=N'$specNameLiteral')
BEGIN
    CREATE DATABASE AUDIT SPECIFICATION $qSpec
    FOR SERVER AUDIT $qAudit
        ADD (SCHEMA_OBJECT_ACCESS_GROUP)
    WITH (STATE = ON);
END
ELSE
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION $qSpec WITH (STATE = ON);
END;
"@

    [void](Invoke-DBACentralNonQuery `
        -ServerInstance $serverInstance `
        -DatabaseName $databaseName `
        -Sql $dbSql `
        -Credential $SourceSqlCredential `
        -CommandTimeoutSeconds $CommandTimeoutSeconds `
        -ApplicationName 'DBACentralRepository TableAccess Audit Installer')

    Write-Host "Audit enabled: $serverInstance / $databaseName -> $auditPath" -ForegroundColor Green
}
