[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepositoryServerInstance,

    [string]$RepositoryDatabase = 'DBACentralRepository',

    [string]$ServerListPath,

    [System.Management.Automation.PSCredential]$RepositorySqlCredential,

    [System.Management.Automation.PSCredential]$SourceSqlCredential,

    [int]$CommandTimeoutSeconds = 60,

    [switch]$IncludeSystemDatabases,

    [string]$CollectorVersion = '1.0'
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
        -ApplicationName 'DBACentralRepository PERF Collector'
}

function Invoke-RepositoryScalar {
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
        -ApplicationName 'DBACentralRepository PERF Collector'
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
        -ApplicationName 'DBACentralRepository PERF Collector')
}

function Invoke-SourceTable {
    param(
        [Parameter(Mandatory)]
        [string]$ServerInstance,

        [Parameter(Mandatory)]
        [string]$Sql
    )

    Invoke-DBACentralDataTable `
        -ServerInstance $ServerInstance `
        -DatabaseName 'master' `
        -Sql $Sql `
        -Credential $SourceSqlCredential `
        -Parameters @{} `
        -CommandTimeoutSeconds $CommandTimeoutSeconds `
        -ApplicationName 'DBACentralRepository PERF Collector'
}

function Add-PerfCommonColumns {
    param(
        [Parameter(Mandatory)]
        [System.Data.DataTable]$Table,

        [Parameter(Mandatory)]
        [long]$SampleBatchId,

        [Parameter(Mandatory)]
        [long]$InstanceId,

        [Parameter(Mandatory)]
        [datetime]$CapturedAt
    )

    foreach ($definition in @(
        @('SampleBatchId',[long]),
        @('InstanceId',[long]),
        @('CapturedAt',[datetime])
    )) {
        if (-not $Table.Columns.Contains($definition[0])) {
            [void]$Table.Columns.Add($definition[0],$definition[1])
        }
    }

    foreach ($row in $Table.Rows) {
        $row['SampleBatchId'] = $SampleBatchId
        $row['InstanceId'] = $InstanceId
        $row['CapturedAt'] = $CapturedAt
    }

    Write-Output -NoEnumerate $Table
}

function Write-PerfBulk {
    param(
        [Parameter(Mandatory)]
        [System.Data.DataTable]$Table,

        [Parameter(Mandatory)]
        [string]$DestinationTable
    )

    if ($Table.Rows.Count -eq 0) {
        return
    }

    # New-DBACentralSqlConnection is already used by existing DBACentralRepository
    # collectors. We intentionally keep the same transport convention.
    $connection = New-DBACentralSqlConnection `
        -ServerInstance $RepositoryServerInstance `
        -DatabaseName $RepositoryDatabase `
        -Credential $RepositorySqlCredential `
        -ApplicationName 'DBACentralRepository PERF Bulk Copy'

    $bulkCopy = $null

    try {
        $connection.Open()

        $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($connection)
        $bulkCopy.DestinationTableName = $DestinationTable
        $bulkCopy.BatchSize = 1000
        $bulkCopy.BulkCopyTimeout = $CommandTimeoutSeconds

        foreach ($column in $Table.Columns) {
            [void]$bulkCopy.ColumnMappings.Add(
                $column.ColumnName,
                $column.ColumnName
            )
        }

        $bulkCopy.WriteToServer($Table)
    }
    finally {
        if ($null -ne $bulkCopy) {
            $bulkCopy.Dispose()
        }

        if ($null -ne $connection) {
            $connection.Dispose()
        }
    }
}

function Get-TargetInstances {
    if ([string]::IsNullOrWhiteSpace($ServerListPath)) {
        return Invoke-RepositoryTable -Sql @'
SELECT
    [InstanceId],
    [ServerInstance]
FROM [dbo].[Instance]
WHERE [IsEnabled] = 1
  AND ISNULL([IsReachable],1) = 1
ORDER BY [ServerInstance];
'@
    }

    $result = New-Object System.Data.DataTable
    [void]$result.Columns.Add('InstanceId',[long])
    [void]$result.Columns.Add('ServerInstance',[string])

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

        $instanceId = Invoke-RepositoryScalar -Sql @'
SELECT TOP (1) [InstanceId]
FROM [dbo].[Instance]
WHERE [ServerInstance] = @ServerInstance;
'@ -Parameters @{
            ServerInstance = $serverInstance
        }

        if ($null -eq $instanceId -or $instanceId -is [DBNull]) {
            Write-Warning "Brak instancji w dbo.Instance: $serverInstance"
            continue
        }

        $row = $result.NewRow()
        $row['InstanceId'] = [long]$instanceId
        $row['ServerInstance'] = $serverInstance
        [void]$result.Rows.Add($row)
    }

    Write-Output -NoEnumerate $result
}

$databaseFilter =
    if ($IncludeSystemDatabases) {
        'd.database_id IS NOT NULL'
    }
    else {
        'd.database_id > 4'
    }

$instances = Get-TargetInstances

foreach ($instance in $instances.Rows) {
    $instanceId = [long]$instance['InstanceId']
    $serverInstance = [string]$instance['ServerInstance']
    $started = Get-Date
    $sampleBatchId = $null
    $capturedAt = Get-Date
    $status = 'SUCCESS'
    $errors = New-Object System.Collections.Generic.List[string]

    Write-Host "PERF: $serverInstance" -ForegroundColor Cyan

    try {
        $sampleBatchId = [long](Invoke-RepositoryScalar -Sql @'
DECLARE @SampleBatchId bigint;

EXEC [perf].[usp_StartSampleBatch]
    @InstanceId = @InstanceId,
    @CollectorHost = @CollectorHost,
    @CollectorUser = @CollectorUser,
    @CollectorVersion = @CollectorVersion,
    @SampleBatchId = @SampleBatchId OUTPUT;

SELECT @SampleBatchId;
'@ -Parameters @{
            InstanceId = $instanceId
            CollectorHost = [Environment]::MachineName
            CollectorUser = [Environment]::UserName
            CollectorVersion = $CollectorVersion
        })

        # ---------------------------------------------------------------------
        # CPU / workload - cumulative plan-cache attribution by database.
        # ---------------------------------------------------------------------
        try {
            $cpu = Invoke-SourceTable `
                -ServerInstance $serverInstance `
                -Sql @"
;WITH Q AS
(
    SELECT
        CONVERT(int,PA.value) AS DatabaseId,
        QS.execution_count,
        QS.total_worker_time,
        QS.total_elapsed_time,
        QS.total_logical_reads,
        QS.total_logical_writes,
        QS.total_physical_reads
    FROM sys.dm_exec_query_stats AS QS
    CROSS APPLY sys.dm_exec_plan_attributes(QS.plan_handle) AS PA
    WHERE PA.attribute = 'dbid'
      AND PA.value IS NOT NULL
)
SELECT
    D.database_id AS DatabaseId,
    D.name AS DatabaseName,
    COUNT_BIG(*) AS CachedQueryCount,
    SUM(CONVERT(bigint,Q.execution_count)) AS ExecutionCount,
    SUM(CONVERT(bigint,Q.total_worker_time / 1000)) AS CpuMs,
    SUM(CONVERT(bigint,Q.total_elapsed_time / 1000)) AS ElapsedMs,
    SUM(CONVERT(bigint,Q.total_logical_reads)) AS LogicalReads,
    SUM(CONVERT(bigint,Q.total_logical_writes)) AS LogicalWrites,
    SUM(CONVERT(bigint,Q.total_physical_reads)) AS PhysicalReads
FROM Q
INNER JOIN sys.databases AS D
    ON D.database_id = Q.DatabaseId
WHERE $databaseFilter
GROUP BY D.database_id, D.name;
"@

            $cpu = Add-PerfCommonColumns `
                -Table $cpu `
                -SampleBatchId $sampleBatchId `
                -InstanceId $instanceId `
                -CapturedAt $capturedAt

            Write-PerfBulk -Table $cpu -DestinationTable '[perf].[DatabaseCpuSnapshot]'
        }
        catch {
            $status = 'PARTIAL'
            $errors.Add("CPU: $($_.Exception.Message)")
        }

        # ---------------------------------------------------------------------
        # File I/O - cumulative counters.
        # ---------------------------------------------------------------------
        try {
            $io = Invoke-SourceTable `
                -ServerInstance $serverInstance `
                -Sql @"
SELECT
    V.database_id AS DatabaseId,
    D.name AS DatabaseName,
    V.file_id AS FileId,
    MF.name AS LogicalFileName,
    CASE MF.type WHEN 0 THEN 'DATA' WHEN 1 THEN 'LOG' ELSE 'OTHER' END AS FileType,
    V.num_of_reads AS NumOfReads,
    V.num_of_bytes_read AS NumOfBytesRead,
    V.io_stall_read_ms AS IoStallReadMs,
    V.num_of_writes AS NumOfWrites,
    V.num_of_bytes_written AS NumOfBytesWritten,
    V.io_stall_write_ms AS IoStallWriteMs,
    V.io_stall AS IoStallMs,
    V.size_on_disk_bytes AS SizeOnDiskBytes,
    V.sample_ms AS SampleMs
FROM sys.dm_io_virtual_file_stats(NULL,NULL) AS V
INNER JOIN sys.databases AS D
    ON D.database_id = V.database_id
LEFT JOIN sys.master_files AS MF
    ON MF.database_id = V.database_id
   AND MF.file_id = V.file_id
WHERE $databaseFilter;
"@

            $io = Add-PerfCommonColumns `
                -Table $io `
                -SampleBatchId $sampleBatchId `
                -InstanceId $instanceId `
                -CapturedAt $capturedAt

            Write-PerfBulk -Table $io -DestinationTable '[perf].[FileIoSnapshot]'
        }
        catch {
            $status = 'PARTIAL'
            $errors.Add("IO: $($_.Exception.Message)")
        }

        # ---------------------------------------------------------------------
        # Buffer Pool.
        # ---------------------------------------------------------------------
        try {
            $memoryWhere =
                if ($IncludeSystemDatabases) {
                    'BD.database_id IS NOT NULL AND BD.database_id <> 32767'
                }
                else {
                    'BD.database_id > 4 AND BD.database_id <> 32767'
                }

            $memory = Invoke-SourceTable `
                -ServerInstance $serverInstance `
                -Sql @"
SELECT
    BD.database_id AS DatabaseId,
    DB_NAME(BD.database_id) AS DatabaseName,
    COUNT_BIG(*) AS BufferPoolPages,
    CAST(COUNT_BIG(*) * 8.0 / 1024.0 AS decimal(19,2)) AS BufferPoolMB,
    SUM(CASE WHEN BD.is_modified = 1 THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS DirtyPages,
    CAST(
        SUM(CASE WHEN BD.is_modified = 1 THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END)
        * 8.0 / 1024.0
        AS decimal(19,2)
    ) AS DirtyPagesMB
FROM sys.dm_os_buffer_descriptors AS BD
WHERE $memoryWhere
GROUP BY BD.database_id;
"@

            $memory = Add-PerfCommonColumns `
                -Table $memory `
                -SampleBatchId $sampleBatchId `
                -InstanceId $instanceId `
                -CapturedAt $capturedAt

            Write-PerfBulk -Table $memory -DestinationTable '[perf].[DatabaseMemorySnapshot]'
        }
        catch {
            $status = 'PARTIAL'
            $errors.Add("MEMORY: $($_.Exception.Message)")
        }

        # ---------------------------------------------------------------------
        # Log / transactions from SQLServer:Databases perf counters.
        # Counter values are stored raw. Reports calculate deltas.
        # ---------------------------------------------------------------------
        try {
            $systemDbClause =
                if ($IncludeSystemDatabases) {
                    "1 = 1"
                }
                else {
                    "PC.instance_name NOT IN ('master','model','msdb','tempdb','_Total')"
                }

            $log = Invoke-SourceTable `
                -ServerInstance $serverInstance `
                -Sql @"
SELECT
    PC.instance_name AS DatabaseName,
    MAX(CASE WHEN PC.counter_name = 'Transactions/sec'
             THEN CONVERT(bigint,PC.cntr_value) END) AS TransactionsCounter,
    MAX(CASE WHEN PC.counter_name = 'Log Bytes Flushed/sec'
             THEN CONVERT(bigint,PC.cntr_value) END) AS LogBytesFlushedCounter,
    MAX(CASE WHEN PC.counter_name = 'Log Flushes/sec'
             THEN CONVERT(bigint,PC.cntr_value) END) AS LogFlushesCounter,
    MAX(CASE WHEN PC.counter_name = 'Log Flush Waits/sec'
             THEN CONVERT(bigint,PC.cntr_value) END) AS LogFlushWaitsCounter,
    MAX(CASE WHEN PC.counter_name = 'Log Flush Wait Time'
             THEN CONVERT(bigint,PC.cntr_value) END) AS LogFlushWaitTimeMs,
    MAX(CASE WHEN PC.counter_name = 'Log Growths'
             THEN CONVERT(bigint,PC.cntr_value) END) AS LogGrowthsCounter,
    MAX(CASE WHEN PC.counter_name = 'Percent Log Used'
             THEN CONVERT(decimal(9,4),PC.cntr_value) END) AS PercentLogUsed
FROM sys.dm_os_performance_counters AS PC
WHERE PC.object_name LIKE '%:Databases'
  AND PC.counter_name IN
  (
      'Transactions/sec',
      'Log Bytes Flushed/sec',
      'Log Flushes/sec',
      'Log Flush Waits/sec',
      'Log Flush Wait Time',
      'Log Growths',
      'Percent Log Used'
  )
  AND $systemDbClause
GROUP BY PC.instance_name
HAVING PC.instance_name <> '_Total';
"@

            $log = Add-PerfCommonColumns `
                -Table $log `
                -SampleBatchId $sampleBatchId `
                -InstanceId $instanceId `
                -CapturedAt $capturedAt

            Write-PerfBulk -Table $log -DestinationTable '[perf].[DatabaseLogSnapshot]'
        }
        catch {
            $status = 'PARTIAL'
            $errors.Add("LOG: $($_.Exception.Message)")
        }

        # ---------------------------------------------------------------------
        # Current concurrency / request waits.
        # ---------------------------------------------------------------------
        try {
            $requests = Invoke-SourceTable `
                -ServerInstance $serverInstance `
                -Sql @"
SELECT
    R.database_id AS DatabaseId,
    DB_NAME(R.database_id) AS DatabaseName,
    COUNT(*) AS ActiveRequests,
    SUM(CASE WHEN R.status = 'running' THEN 1 ELSE 0 END) AS RunningRequests,
    SUM(CASE WHEN R.status = 'suspended' THEN 1 ELSE 0 END) AS SuspendedRequests,
    SUM(CASE WHEN ISNULL(R.blocking_session_id,0) <> 0 THEN 1 ELSE 0 END) AS BlockedRequests,
    SUM(CONVERT(bigint,R.cpu_time)) AS CurrentCpuMs,
    SUM(CONVERT(bigint,R.total_elapsed_time)) AS CurrentElapsedMs,
    SUM(CONVERT(bigint,R.reads)) AS CurrentReads,
    SUM(CONVERT(bigint,R.writes)) AS CurrentWrites,
    SUM(CONVERT(bigint,R.logical_reads)) AS CurrentLogicalReads,
    SUM(CONVERT(bigint,ISNULL(R.wait_time,0))) AS CurrentWaitMs,
    SUM(CASE WHEN R.wait_type LIKE 'LCK[_]%' THEN 1 ELSE 0 END) AS LockWaitRequests,
    SUM(CASE WHEN
                 R.wait_type LIKE 'PAGEIOLATCH[_]%'
              OR R.wait_type IN ('WRITELOG','ASYNC_IO_COMPLETION','IO_COMPLETION')
             THEN 1 ELSE 0 END) AS IoWaitRequests
FROM sys.dm_exec_requests AS R
WHERE R.session_id <> @@SPID
  AND R.database_id IS NOT NULL
  AND $(if ($IncludeSystemDatabases) { 'R.database_id IS NOT NULL' } else { 'R.database_id > 4' })
GROUP BY R.database_id;
"@

            $requests = Add-PerfCommonColumns `
                -Table $requests `
                -SampleBatchId $sampleBatchId `
                -InstanceId $instanceId `
                -CapturedAt $capturedAt

            Write-PerfBulk -Table $requests -DestinationTable '[perf].[DatabaseConcurrencySnapshot]'
        }
        catch {
            $status = 'PARTIAL'
            $errors.Add("CONCURRENCY: $($_.Exception.Message)")
        }
    }
    catch {
        $status = 'FAILED'
        $errors.Add($_.Exception.Message)
    }
    finally {
        if ($null -ne $sampleBatchId) {
            $durationMs = [int]((Get-Date) - $started).TotalMilliseconds
            $errorText =
                if ($errors.Count -gt 0) {
                    ($errors -join ' | ')
                }
                else {
                    $null
                }

            try {
                Invoke-RepositoryNonQuery -Sql @'
EXEC [perf].[usp_FinishSampleBatch]
    @SampleBatchId = @SampleBatchId,
    @CollectionStatus = @CollectionStatus,
    @DurationMs = @DurationMs,
    @ErrorMessage = @ErrorMessage;
'@ -Parameters @{
                    SampleBatchId = $sampleBatchId
                    CollectionStatus = $status
                    DurationMs = $durationMs
                    ErrorMessage = $errorText
                }
            }
            catch {
                Write-Warning "Nie udało się zamknąć SampleBatch $sampleBatchId : $($_.Exception.Message)"
            }
        }
    }

    if ($status -eq 'SUCCESS') {
        Write-Host "  SUCCESS" -ForegroundColor Green
    }
    elseif ($status -eq 'PARTIAL') {
        Write-Warning "  PARTIAL: $($errors -join ' | ')"
    }
    else {
        Write-Warning "  FAILED: $($errors -join ' | ')"
    }
}
