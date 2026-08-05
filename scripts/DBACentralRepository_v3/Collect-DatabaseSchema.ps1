[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepositoryServerInstance,

    [string]$RepositoryDatabase = 'DBACentralRepository',

    [string]$ServerListPath,

    [System.Management.Automation.PSCredential]$RepositorySqlCredential,

    [System.Management.Automation.PSCredential]$SourceSqlCredential,

    [switch]$IncludeSystemDatabases,

    [switch]$StoreDefinitions,

    [int]$CommandTimeoutSeconds = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path `
    $PSScriptRoot `
    'modules\DBACentralRepository.Common\DBACentralRepository.Common.psd1'

Import-Module -Name $modulePath -Force -ErrorAction Stop


function Invoke-RepositoryTable {
    param(
        [Parameter(Mandatory)]
        [string]$Sql,

        [hashtable]$Parameters = @{}
    )

    Invoke-DBACentralDataTable `
        -ServerInstance $RepositoryServerInstance `
        -DatabaseName $RepositoryDatabase `
        -Sql $Sql `
        -Credential $RepositorySqlCredential `
        -Parameters $Parameters `
        -CommandTimeoutSeconds $CommandTimeoutSeconds `
        -ApplicationName 'DBACentralRepository Schema Collector'
}


function Invoke-RepositoryNonQuery {
    param(
        [Parameter(Mandatory)]
        [string]$Sql,

        [hashtable]$Parameters = @{}
    )

    [void](Invoke-DBACentralNonQuery `
        -ServerInstance $RepositoryServerInstance `
        -DatabaseName $RepositoryDatabase `
        -Sql $Sql `
        -Credential $RepositorySqlCredential `
        -Parameters $Parameters `
        -CommandTimeoutSeconds $CommandTimeoutSeconds `
        -ApplicationName 'DBACentralRepository Schema Collector')
}


function Get-RepositoryScalar {
    param(
        [Parameter(Mandatory)]
        [string]$Sql,

        [hashtable]$Parameters = @{}
    )

    Invoke-DBACentralScalar `
        -ServerInstance $RepositoryServerInstance `
        -DatabaseName $RepositoryDatabase `
        -Sql $Sql `
        -Credential $RepositorySqlCredential `
        -Parameters $Parameters `
        -CommandTimeoutSeconds $CommandTimeoutSeconds `
        -ApplicationName 'DBACentralRepository Schema Collector'
}


function Add-SnapshotColumns {
    param(
        [Parameter(Mandatory)]
        [System.Data.DataTable]$Table,

        [Parameter(Mandatory)]
        [long]$ScanRunId,

        [Parameter(Mandatory)]
        [long]$InstanceId,

        [Parameter(Mandatory)]
        [string]$DatabaseName
    )

    foreach ($definition in @(
        @('ScanRunId',[long]),
        @('InstanceId',[long]),
        @('CapturedAt',[datetime]),
        @('DatabaseName',[string])
    )) {
        if (-not $Table.Columns.Contains($definition[0])) {
            [void]$Table.Columns.Add($definition[0],$definition[1])
        }
    }

    $capturedAt = [datetime]::Now

    foreach ($row in $Table.Rows) {
        $row['ScanRunId'] = $ScanRunId
        $row['InstanceId'] = $InstanceId
        $row['CapturedAt'] = $capturedAt
        $row['DatabaseName'] = $DatabaseName
    }

    Write-Output -NoEnumerate $Table
}


$scanRunId = [long](Get-RepositoryScalar `
    -Sql @'
DECLARE @ScanRunId bigint;

EXEC [dbo].[usp_StartScan]
    @ScanType = 'SCHEMA',
    @CollectorHost = @CollectorHost,
    @CollectorUser = @CollectorUser,
    @RepositoryServer = @RepositoryServer,
    @ScanRunId = @ScanRunId OUTPUT;

SELECT @ScanRunId;
'@ `
    -Parameters @{
        CollectorHost = [Environment]::MachineName
        CollectorUser = [Environment]::UserName
        RepositoryServer = $RepositoryServerInstance
    })

$instanceCount = 0
$objectCount = 0
$errorCount = 0

try {
    if ([string]::IsNullOrWhiteSpace($ServerListPath)) {
        $instances = Invoke-RepositoryTable -Sql @'
SELECT
    [InstanceId],
    [ServerInstance]
FROM [dbo].[Instance]
WHERE [IsReachable] = 1
ORDER BY [ServerInstance];
'@
    }
    else {
        $instances = New-Object System.Data.DataTable
        [void]$instances.Columns.Add('InstanceId',[long])
        [void]$instances.Columns.Add('ServerInstance',[string])

        foreach ($entry in Import-Csv -LiteralPath $ServerListPath) {
            $serverInstance =
                if ($entry.PSObject.Properties.Name -contains 'ServerInstance') {
                    [string]$entry.ServerInstance
                }
                elseif ($entry.PSObject.Properties.Name -contains 'Server') {
                    [string]$entry.Server
                }
                else {
                    [string]$entry.Instance
                }

            if ([string]::IsNullOrWhiteSpace($serverInstance)) {
                continue
            }

            $instanceId = Get-RepositoryScalar `
                -Sql @'
SELECT TOP (1) [InstanceId]
FROM [dbo].[Instance]
WHERE [ServerInstance] = @ServerInstance;
'@ `
                -Parameters @{
                    ServerInstance = $serverInstance
                }

            if ($null -ne $instanceId -and $instanceId -isnot [DBNull]) {
                $row = $instances.NewRow()
                $row['InstanceId'] = [long]$instanceId
                $row['ServerInstance'] = $serverInstance
                [void]$instances.Rows.Add($row)
            }
        }
    }

    $objectSql = @'
SELECT
    O.[object_id] AS [ObjectId],
    S.[name] AS [SchemaName],
    O.[name] AS [ObjectName],
    O.[type] AS [ObjectType],
    O.[type_desc] AS [ObjectTypeDesc],
    O.[create_date] AS [CreateDate],
    O.[modify_date] AS [ModifyDate],
    HASHBYTES
    (
        'SHA2_256',
        CONVERT(nvarchar(max),COALESCE(M.[definition],N''))
    ) AS [DefinitionHash],
    CASE
        WHEN @StoreDefinitions = 1
            THEN M.[definition]
        ELSE NULL
    END AS [DefinitionText]
FROM [sys].[objects] AS O
INNER JOIN [sys].[schemas] AS S
    ON S.[schema_id] = O.[schema_id]
LEFT JOIN [sys].[sql_modules] AS M
    ON M.[object_id] = O.[object_id]
WHERE O.[is_ms_shipped] = 0
  AND O.[type] IN ('U','V')
ORDER BY S.[name],O.[name];
'@

    $columnSql = @'
SELECT
    O.[object_id] AS [ObjectId],
    S.[name] AS [SchemaName],
    O.[name] AS [ObjectName],
    O.[type] AS [ObjectType],
    C.[column_id] AS [ColumnId],
    C.[name] AS [ColumnName],
    T.[name] AS [DataTypeName],
    C.[max_length] AS [MaxLength],
    C.[precision] AS [PrecisionValue],
    C.[scale] AS [ScaleValue],
    C.[is_nullable] AS [IsNullable],
    C.[is_identity] AS [IsIdentity],
    C.[is_computed] AS [IsComputed],
    C.[collation_name] AS [CollationName],
    DC.[definition] AS [DefaultDefinition],
    CC.[definition] AS [ComputedDefinition],
    HASHBYTES
    (
        'SHA2_256',
        CONVERT
        (
            nvarchar(max),
            CONCAT
            (
                T.[name],N'|',C.[max_length],N'|',
                C.[precision],N'|',C.[scale],N'|',
                C.[is_nullable],N'|',C.[is_identity],N'|',
                C.[is_computed],N'|',
                COALESCE(C.[collation_name],N''),N'|',
                COALESCE(DC.[definition],N''),N'|',
                COALESCE(CC.[definition],N'')
            )
        )
    ) AS [ColumnSignatureHash]
FROM [sys].[objects] AS O
INNER JOIN [sys].[schemas] AS S
    ON S.[schema_id] = O.[schema_id]
INNER JOIN [sys].[columns] AS C
    ON C.[object_id] = O.[object_id]
INNER JOIN [sys].[types] AS T
    ON T.[user_type_id] = C.[user_type_id]
LEFT JOIN [sys].[default_constraints] AS DC
    ON DC.[object_id] = C.[default_object_id]
LEFT JOIN [sys].[computed_columns] AS CC
    ON CC.[object_id] = C.[object_id]
   AND CC.[column_id] = C.[column_id]
WHERE O.[is_ms_shipped] = 0
  AND O.[type] IN ('U','V')
ORDER BY S.[name],O.[name],C.[column_id];
'@

    foreach ($instance in $instances.Rows) {
        $instanceCount++
        $instanceId = [long]$instance['InstanceId']
        $serverInstance = [string]$instance['ServerInstance']

        Write-Host "Instancja: $serverInstance" -ForegroundColor Cyan

        try {
            $databaseFilter =
                if ($IncludeSystemDatabases) {
                    ''
                }
                else {
                    'AND [database_id] > 4'
                }

            $databases = Invoke-DBACentralDataTable `
                -ServerInstance $serverInstance `
                -DatabaseName 'master' `
                -Credential $SourceSqlCredential `
                -CommandTimeoutSeconds $CommandTimeoutSeconds `
                -Sql @"
SELECT [name] AS [DatabaseName]
FROM [sys].[databases]
WHERE [state] = 0
  AND [source_database_id] IS NULL
  $databaseFilter
ORDER BY [name];
"@
        }
        catch {
            $errorCount++
            Invoke-RepositoryNonQuery `
                -Sql @'
EXEC [dbo].[usp_LogScanError]
    @ScanRunId=@ScanRunId,
    @InstanceId=@InstanceId,
    @ModuleName='SCHEMA',
    @ObjectName=@ObjectName,
    @StageName='DATABASE_LIST',
    @ErrorNumber=NULL,
    @ErrorMessage=@ErrorMessage;
'@ `
                -Parameters @{
                    ScanRunId = $scanRunId
                    InstanceId = $instanceId
                    ObjectName = $serverInstance
                    ErrorMessage = $_.Exception.Message
                }
            continue
        }

        foreach ($database in $databases.Rows) {
            $databaseName = [string]$database['DatabaseName']
            $startedAt = [datetime]::Now

            Invoke-RepositoryNonQuery `
                -Sql @'
INSERT INTO [db].[DatabaseSchemaCollectionStatus]
(
    [ScanRunId],[InstanceId],[DatabaseName],
    [StartedAt],[CollectionStatus]
)
VALUES
(
    @ScanRunId,@InstanceId,@DatabaseName,
    @StartedAt,'STARTED'
);
'@ `
                -Parameters @{
                    ScanRunId = $scanRunId
                    InstanceId = $instanceId
                    DatabaseName = $databaseName
                    StartedAt = $startedAt
                }

            try {
                $objects = Invoke-DBACentralDataTable `
                    -ServerInstance $serverInstance `
                    -DatabaseName $databaseName `
                    -Credential $SourceSqlCredential `
                    -CommandTimeoutSeconds $CommandTimeoutSeconds `
                    -Sql $objectSql `
                    -Parameters @{
                        StoreDefinitions =
                            if ($StoreDefinitions) { 1 } else { 0 }
                    }

                $columns = Invoke-DBACentralDataTable `
                    -ServerInstance $serverInstance `
                    -DatabaseName $databaseName `
                    -Credential $SourceSqlCredential `
                    -CommandTimeoutSeconds $CommandTimeoutSeconds `
                    -Sql $columnSql

                $objects = Add-SnapshotColumns `
                    -Table $objects `
                    -ScanRunId $scanRunId `
                    -InstanceId $instanceId `
                    -DatabaseName $databaseName

                $columns = Add-SnapshotColumns `
                    -Table $columns `
                    -ScanRunId $scanRunId `
                    -InstanceId $instanceId `
                    -DatabaseName $databaseName

                [void](Write-DBACentralBulkCopy `
                    -DataTable $objects `
                    -DestinationTable '[db].[DatabaseObjectSnapshot]' `
                    -ServerInstance $RepositoryServerInstance `
                    -DatabaseName $RepositoryDatabase `
                    -Credential $RepositorySqlCredential `
                    -CommandTimeoutSeconds $CommandTimeoutSeconds)

                [void](Write-DBACentralBulkCopy `
                    -DataTable $columns `
                    -DestinationTable '[db].[DatabaseColumnSnapshot]' `
                    -ServerInstance $RepositoryServerInstance `
                    -DatabaseName $RepositoryDatabase `
                    -Credential $RepositorySqlCredential `
                    -CommandTimeoutSeconds $CommandTimeoutSeconds)

                $objectCount += $objects.Rows.Count + $columns.Rows.Count

                Invoke-RepositoryNonQuery `
                    -Sql @'
UPDATE [db].[DatabaseSchemaCollectionStatus]
SET
    [CompletedAt]=SYSDATETIME(),
    [CollectionStatus]='SUCCESS',
    [ObjectCount]=@ObjectCount,
    [ColumnCount]=@ColumnCount,
    [ErrorMessage]=NULL
WHERE [ScanRunId]=@ScanRunId
  AND [InstanceId]=@InstanceId
  AND [DatabaseName]=@DatabaseName;
'@ `
                    -Parameters @{
                        ScanRunId = $scanRunId
                        InstanceId = $instanceId
                        DatabaseName = $databaseName
                        ObjectCount = $objects.Rows.Count
                        ColumnCount = $columns.Rows.Count
                    }

                Write-Host (
                    "  $databaseName: obiekty=$($objects.Rows.Count), " +
                    "kolumny=$($columns.Rows.Count)"
                ) -ForegroundColor Green
            }
            catch {
                $errorCount++

                Invoke-RepositoryNonQuery `
                    -Sql @'
UPDATE [db].[DatabaseSchemaCollectionStatus]
SET
    [CompletedAt]=SYSDATETIME(),
    [CollectionStatus]='FAILED',
    [ErrorMessage]=@ErrorMessage
WHERE [ScanRunId]=@ScanRunId
  AND [InstanceId]=@InstanceId
  AND [DatabaseName]=@DatabaseName;

EXEC [dbo].[usp_LogScanError]
    @ScanRunId=@ScanRunId,
    @InstanceId=@InstanceId,
    @ModuleName='SCHEMA',
    @ObjectName=@ObjectName,
    @StageName='DATABASE_SCHEMA',
    @ErrorNumber=NULL,
    @ErrorMessage=@ErrorMessage;
'@ `
                    -Parameters @{
                        ScanRunId = $scanRunId
                        InstanceId = $instanceId
                        DatabaseName = $databaseName
                        ObjectName = "$serverInstance/$databaseName"
                        ErrorMessage = $_.Exception.Message
                    }

                Write-Warning (
                    "Błąd skanowania $serverInstance/$databaseName: " +
                    $_.Exception.Message
                )
            }
        }
    }
}
finally {
    $status =
        if ($errorCount -eq 0) {
            'SUCCESS'
        }
        else {
            'COMPLETED_WITH_ERRORS'
        }

    Invoke-RepositoryNonQuery `
        -Sql @'
EXEC [dbo].[usp_FinishScan]
    @ScanRunId=@ScanRunId,
    @Status=@Status,
    @InstanceCount=@InstanceCount,
    @ObjectCount=@ObjectCount,
    @ErrorCount=@ErrorCount;
'@ `
        -Parameters @{
            ScanRunId = $scanRunId
            Status = $status
            InstanceCount = $instanceCount
            ObjectCount = $objectCount
            ErrorCount = $errorCount
        }
}

Write-Host ''
Write-Host "ScanRunId: $scanRunId" -ForegroundColor Cyan
Write-Host "Instancje: $instanceCount"
Write-Host "Obiekty i kolumny: $objectCount"
Write-Host "Błędy: $errorCount"

if ($errorCount -gt 0) {
    exit 2
}
