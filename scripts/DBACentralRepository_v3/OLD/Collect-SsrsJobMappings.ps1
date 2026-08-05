[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepositoryServerInstance,

    [string]$RepositoryDatabase = 'DBACentralRepository',

    [string]$ServerListPath,

    [long]$ScanRunId,

    [System.Management.Automation.PSCredential]$RepositorySqlCredential,

    [System.Management.Automation.PSCredential]$SourceSqlCredential,

    [int]$CommandTimeoutSeconds = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path `
    $PSScriptRoot `
    'modules\DBACentralRepository.Common\DBACentralRepository.Common.psd1'

Import-Module `
    -Name $modulePath `
    -Force `
    -ErrorAction Stop



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
        -ApplicationName 'DBACentralRepository SSRS Scalar'
}

function Write-SsrsMappings {
    param(
        [Parameter(Mandatory)]
        [System.Data.DataTable]$SourceTable,

        [Parameter(Mandatory)]
        [long]$InstanceId,

        [Parameter(Mandatory)]
        [long]$CurrentScanRunId,

        [Parameter(Mandatory)]
        [string]$ReportServerDatabase
    )

    $target = New-Object System.Data.DataTable
    [void]$target.Columns.Add('ScanRunId', [long])
    [void]$target.Columns.Add('InstanceId', [long])
    [void]$target.Columns.Add('ReportServerDatabase', [string])
    [void]$target.Columns.Add('SqlAgentJobId', [Guid])
    [void]$target.Columns.Add('SqlAgentJobName', [string])
    [void]$target.Columns.Add('ScheduleId', [Guid])
    [void]$target.Columns.Add('SubscriptionId', [Guid])
    [void]$target.Columns.Add('ReportId', [Guid])
    [void]$target.Columns.Add('ReportName', [string])
    [void]$target.Columns.Add('ReportPath', [string])
    [void]$target.Columns.Add('SubscriptionDescription', [string])
    [void]$target.Columns.Add('SubscriptionOwner', [string])
    [void]$target.Columns.Add('DeliveryExtension', [string])
    [void]$target.Columns.Add('LastStatus', [string])
    [void]$target.Columns.Add('LastRunTime', [datetime])
    [void]$target.Columns.Add('ScheduleName', [string])
    [void]$target.Columns.Add('ScheduleNextRunTime', [datetime])
    [void]$target.Columns.Add('ScheduleLastRunTime', [datetime])
    [void]$target.Columns.Add('SsrsJobType', [string])
    [void]$target.Columns.Add('FriendlyJobName', [string])
    [void]$target.Columns.Add('CapturedAt', [datetime])

    $capturedAt = [datetime]::Now

    foreach ($sourceRow in $SourceTable.Rows) {
        $row = $target.NewRow()

        $row['ScanRunId'] = $CurrentScanRunId
        $row['InstanceId'] = $InstanceId
        $row['ReportServerDatabase'] = $ReportServerDatabase
        $row['SqlAgentJobId'] = [Guid]$sourceRow['SqlAgentJobId']
        $row['SqlAgentJobName'] = [string]$sourceRow['SqlAgentJobName']

        foreach ($columnName in @(
            'ScheduleId',
            'SubscriptionId',
            'ReportId',
            'ReportName',
            'ReportPath',
            'SubscriptionDescription',
            'SubscriptionOwner',
            'DeliveryExtension',
            'LastStatus',
            'LastRunTime',
            'ScheduleName',
            'ScheduleNextRunTime',
            'ScheduleLastRunTime',
            'SsrsJobType',
            'FriendlyJobName'
        )) {
            $value = $sourceRow[$columnName]

            if ($value -is [DBNull] -or $null -eq $value) {
                $row[$columnName] = [DBNull]::Value
            }
            else {
                $row[$columnName] = $value
            }
        }

        $row['CapturedAt'] = $capturedAt
        [void]$target.Rows.Add($row)
    }

    if ($target.Rows.Count -eq 0) {
        return 0
    }

    $connection = New-DBACentralSqlConnection `
        -ServerInstance $RepositoryServerInstance `
        -DatabaseName $RepositoryDatabase `
        -Credential $RepositorySqlCredential `
        -ApplicationName 'DBACentralRepository SSRS Mapping Bulk Copy'

    $bulkCopy = $null

    try {
        $connection.Open()

        $bulkCopy =
            New-Object System.Data.SqlClient.SqlBulkCopy(
                $connection
            )

        $bulkCopy.DestinationTableName =
            '[job].[SsrsJobMapping]'

        $bulkCopy.BatchSize = 1000
        $bulkCopy.BulkCopyTimeout = $CommandTimeoutSeconds

        foreach ($column in $target.Columns) {
            [void]$bulkCopy.ColumnMappings.Add(
                $column.ColumnName,
                $column.ColumnName
            )
        }

        $bulkCopy.WriteToServer($target)
    }
    finally {
        if ($null -ne $bulkCopy) {
            $bulkCopy.Dispose()
        }

        if ($null -ne $connection) {
            $connection.Dispose()
        }
    }

    return $target.Rows.Count
}


if (-not $PSBoundParameters.ContainsKey('ScanRunId')) {
    $value = Get-RepositoryScalar -Sql @'
SELECT TOP (1) [ScanRunId]
FROM [dbo].[ScanRun]
WHERE [Status] IN ('SUCCESS', 'COMPLETED_WITH_ERRORS')
ORDER BY [ScanRunId] DESC;
'@ -Parameters @{}

    if ($null -eq $value -or $value -is [DBNull]) {
        throw 'Nie znaleziono zakończonego ScanRunId.'
    }

    $ScanRunId = [long]$value
}


if ([string]::IsNullOrWhiteSpace($ServerListPath)) {
    $instances = Invoke-DBACentralDataTable `
        -ServerInstance $RepositoryServerInstance `
        -DatabaseName $RepositoryDatabase `
        -Credential $RepositorySqlCredential `
        -Parameters @{} `
        -Sql @'
SELECT
    [InstanceId],
    [ServerInstance]
FROM [dbo].[Instance]
ORDER BY [ServerInstance];
'@
}
else {
    $csv = Import-Csv -Path $ServerListPath

    $instances = New-Object System.Data.DataTable
    [void]$instances.Columns.Add('InstanceId', [long])
    [void]$instances.Columns.Add('ServerInstance', [string])

    foreach ($item in $csv) {
        $serverInstance =
            if ($item.PSObject.Properties.Name -contains 'ServerInstance') {
                [string]$item.ServerInstance
            }
            elseif ($item.PSObject.Properties.Name -contains 'Server') {
                [string]$item.Server
            }
            else {
                [string]$item.Instance
            }

        $instanceId = Get-RepositoryScalar `
            -Parameters @{
                ServerInstance = $serverInstance
            } `
            -Sql @'
SELECT TOP (1) [InstanceId]
FROM [dbo].[Instance]
WHERE [ServerInstance] = @ServerInstance;
'@

        if ($null -ne $instanceId -and $instanceId -isnot [DBNull]) {
            $row = $instances.NewRow()
            $row['InstanceId'] = [long]$instanceId
            $row['ServerInstance'] = $serverInstance
            [void]$instances.Rows.Add($row)
        }
        else {
            Write-Warning "Brak instancji w repozytorium: $serverInstance"
        }
    }
}


$totalRows = 0
$errorCount = 0

foreach ($instance in $instances.Rows) {
    $instanceId = [long]$instance['InstanceId']
    $serverInstance = [string]$instance['ServerInstance']

    Write-Host "SSRS: $serverInstance" -ForegroundColor Cyan

    try {
        $reportDatabases = Invoke-DBACentralDataTable `
            -ServerInstance $serverInstance `
            -DatabaseName 'master' `
            -Credential $SourceSqlCredential `
            -Parameters @{} `
            -Sql @'
SELECT [name]
FROM sys.databases
WHERE [state] = 0
  AND [name] LIKE N'ReportServer%'
  AND [name] NOT LIKE N'%TempDB'
ORDER BY [name];
'@

        if ($reportDatabases.Rows.Count -eq 0) {
            Write-Host '  Brak bazy ReportServer — pomijam.' -ForegroundColor DarkGray
            continue
        }

        Invoke-DBACentralNonQuery `
            -ServerInstance $RepositoryServerInstance `
            -DatabaseName $RepositoryDatabase `
            -Credential $RepositorySqlCredential `
            -Parameters @{
                ScanRunId = $ScanRunId
                InstanceId = $instanceId
            } `
            -Sql @'
DELETE FROM [job].[SsrsJobMapping]
WHERE [ScanRunId] = @ScanRunId
  AND [InstanceId] = @InstanceId;
'@

        foreach ($databaseRow in $reportDatabases.Rows) {
            $reportServerDatabase = [string]$databaseRow['name']
            $quotedDatabase =
                '[' + $reportServerDatabase.Replace(']', ']]') + ']'

            Write-Host "  Baza: $reportServerDatabase"

            $query = @"
SELECT
    J.[job_id] AS [SqlAgentJobId],
    J.[name] AS [SqlAgentJobName],

    RS.[ScheduleID] AS [ScheduleId],
    RS.[SubscriptionID] AS [SubscriptionId],
    COALESCE(RS.[ReportID], S.[Report_OID]) AS [ReportId],

    C.[Name] AS [ReportName],
    C.[Path] AS [ReportPath],

    S.[Description] AS [SubscriptionDescription],
    U.[UserName] AS [SubscriptionOwner],
    S.[DeliveryExtension],
    S.[LastStatus],
    S.[LastRunTime],

    SCH.[Name] AS [ScheduleName],
    SCH.[NextRunTime] AS [ScheduleNextRunTime],
    SCH.[LastRunTime] AS [ScheduleLastRunTime],

    CASE
        WHEN S.[SubscriptionID] IS NOT NULL
            THEN 'SSRS_SUBSCRIPTION'
        ELSE 'SSRS_SCHEDULE'
    END AS [SsrsJobType],

    CONVERT
    (
        nvarchar(2000),
        CONCAT
        (
            N'SSRS - ',
            COALESCE
            (
                NULLIF(C.[Path], N''),
                NULLIF(C.[Name], N''),
                N'Nieznany raport'
            ),
            CASE
                WHEN NULLIF(S.[Description], N'') IS NOT NULL
                    THEN CONCAT(N' - ', S.[Description])
                ELSE N''
            END
        )
    ) AS [FriendlyJobName]
FROM [msdb].[dbo].[sysjobs] AS J
INNER JOIN $quotedDatabase.[dbo].[ReportSchedule] AS RS
    ON TRY_CONVERT(uniqueidentifier, J.[name]) = RS.[ScheduleID]
LEFT JOIN $quotedDatabase.[dbo].[Subscriptions] AS S
    ON S.[SubscriptionID] = RS.[SubscriptionID]
LEFT JOIN $quotedDatabase.[dbo].[Catalog] AS C
    ON C.[ItemID] = COALESCE(RS.[ReportID], S.[Report_OID])
LEFT JOIN $quotedDatabase.[dbo].[Users] AS U
    ON U.[UserID] = S.[OwnerID]
LEFT JOIN $quotedDatabase.[dbo].[Schedule] AS SCH
    ON SCH.[ScheduleID] = RS.[ScheduleID]
WHERE TRY_CONVERT(uniqueidentifier, J.[name]) IS NOT NULL;
"@

            try {
                $mapping = Invoke-DBACentralDataTable `
                    -ServerInstance $serverInstance `
                    -DatabaseName 'master' `
                    -Credential $SourceSqlCredential `
                    -Parameters @{} `
                    -Sql $query

                $inserted = Write-SsrsMappings `
                    -SourceTable $mapping `
                    -InstanceId $instanceId `
                    -CurrentScanRunId $ScanRunId `
                    -ReportServerDatabase $reportServerDatabase

                $totalRows += $inserted

                Write-Host "    Mapowania: $inserted" -ForegroundColor Green
            }
            catch {
                $errorCount++
                Write-Warning (
                    'Błąd odczytu bazy [{0}] na [{1}]: {2}' -f
                    $reportServerDatabase,
                    $serverInstance,
                    $_.Exception.Message
                )
            }
        }
    }
    catch {
        $errorCount++
        Write-Warning (
            'Błąd instancji [{0}]: {1}' -f
            $serverInstance,
            $_.Exception.Message
        )
    }
}


Write-Host ''
Write-Host 'Kolekcja mapowań SSRS zakończona.' -ForegroundColor Green
Write-Host "ScanRunId: $ScanRunId"
Write-Host "Wiersze mapowania: $totalRows"
Write-Host "Błędy: $errorCount"
