[CmdletBinding()]
param(
    [string]$RepositoryServerInstance = 'localhost',
    [string]$RepositoryDatabase = 'DBACentralRepository',
    [int]$HistoryDays = 35
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-SqlConnection {
    param([string]$ServerInstance,[string]$Database)
    $cs = "Server=$ServerInstance;Database=$Database;Integrated Security=True;TrustServerCertificate=True;Application Name=DBACentralRepository Backup Collector;"
    $cn = [System.Data.SqlClient.SqlConnection]::new($cs)
    $cn.Open()
    $cn
}

function Get-DataTable {
    param(
        $Connection,
        [string]$Sql,
        [hashtable]$Parameters
    )

    $cmd = $Connection.CreateCommand()
    $cmd.CommandTimeout = 120
    $cmd.CommandText = $Sql

    foreach ($k in $Parameters.Keys) {
        $null = $cmd.Parameters.AddWithValue(
            "@$k",
            $Parameters[$k]
        )
    }

    $dt = [System.Data.DataTable]::new()
    $da = [System.Data.SqlClient.SqlDataAdapter]::new($cmd)

    $null = $da.Fill($dt)

    Write-Output -NoEnumerate $dt
}

function Exec-Scalar {
    param($Connection,[string]$Sql,[hashtable]$Parameters)
    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = $Sql
    foreach($k in $Parameters.Keys){ $null = $cmd.Parameters.AddWithValue("@$k",$Parameters[$k]) }
    $cmd.ExecuteScalar()
}

function Exec-NonQuery {
    param($Connection,[string]$Sql,[hashtable]$Parameters)
    $cmd = $Connection.CreateCommand()
    $cmd.CommandTimeout = 120
    $cmd.CommandText = $Sql
    foreach($k in $Parameters.Keys){ $null = $cmd.Parameters.AddWithValue("@$k",$Parameters[$k]) }
    $cmd.ExecuteNonQuery()
}

$repo = New-SqlConnection $RepositoryServerInstance $RepositoryDatabase
$scanRunId = [int64](Exec-Scalar $repo @"
INSERT dbo.ScanRun
(
    ScanType,ScanStartedAt,CollectorHost,CollectorUser,RepositoryServer,
    Status,InstanceCount,ObjectCount,ErrorCount
)
OUTPUT inserted.ScanRunId
VALUES
(
    'BACKUP',SYSDATETIME(),HOST_NAME(),SUSER_SNAME(),@RepositoryServer,
    'RUNNING',0,0,0
);
"@ @{RepositoryServer=$RepositoryServerInstance})

$instanceCount = 0
$objectCount = 0
$errorCount = 0

try {
    $instances = Get-DataTable $repo @"
SELECT InstanceId,ServerInstance
FROM dbo.Instance
WHERE IsEnabled = 1
  AND IsReachable = 1
ORDER BY ServerInstance;
"@ @{}

    foreach($row in $instances.Rows){
        $instanceId = [int64]$row.InstanceId
        $server = [string]$row.ServerInstance
        $target = $null

        try {
            Write-Host "Collecting $server ..."
            $target = New-SqlConnection $server 'msdb'

            $history = Get-DataTable $target @"
SELECT
    CAST(backup_set_id AS int) AS BackupSetId,
    CAST(database_name AS nvarchar(128)) AS DatabaseName,
    CAST([type] AS char(1)) AS BackupType,
    CAST(CASE [type]
        WHEN 'D' THEN N'DATABASE'
        WHEN 'I' THEN N'DIFFERENTIAL'
        WHEN 'L' THEN N'LOG'
        ELSE N'OTHER' END AS nvarchar(60)) AS BackupTypeDescription,
    CAST(ISNULL(is_copy_only,0) AS bit) AS IsCopyOnly,
    backup_start_date AS BackupStartDate,
    backup_finish_date AS BackupFinishDate,
    CAST(DATEDIFF(SECOND,backup_start_date,backup_finish_date) AS int) AS DurationSeconds,
    CAST(backup_size/1048576.0 AS decimal(19,2)) AS BackupSizeMB,
    CAST(compressed_backup_size/1048576.0 AS decimal(19,2)) AS CompressedBackupSizeMB,
    CAST(CASE WHEN compressed_backup_size = 0 THEN NULL
              ELSE backup_size/CONVERT(decimal(38,4),compressed_backup_size) END AS decimal(19,4)) AS CompressionRatio,
    CAST(has_backup_checksums AS bit) AS HasBackupChecksums,
    CAST(is_damaged AS bit) AS IsDamaged,
    CAST(recovery_model AS nvarchar(120)) AS RecoveryModel,
    CAST(first_lsn AS numeric(25,0)) AS FirstLsn,
    CAST(last_lsn AS numeric(25,0)) AS LastLsn,
    CAST(database_backup_lsn AS numeric(25,0)) AS DatabaseBackupLsn,
    CAST(checkpoint_lsn AS numeric(25,0)) AS CheckpointLsn
FROM dbo.backupset
WHERE backup_finish_date >= DATEADD(DAY,-@HistoryDays,GETDATE())
ORDER BY backup_set_id;
"@ @{HistoryDays=$HistoryDays}

            foreach($h in $history.Rows){
                $backupHistoryId = Exec-Scalar $repo @"
MERGE [backup].BackupHistory AS tgt
USING
(
    SELECT
        @ScanRunId AS ScanRunId,@InstanceId AS InstanceId,@DatabaseName AS DatabaseName,
        @BackupSetId AS BackupSetId,@BackupType AS BackupType,@BackupTypeDescription AS BackupTypeDescription,
        @IsCopyOnly AS IsCopyOnly,@BackupStartDate AS BackupStartDate,@BackupFinishDate AS BackupFinishDate,
        @DurationSeconds AS DurationSeconds,@BackupSizeMB AS BackupSizeMB,
        @CompressedBackupSizeMB AS CompressedBackupSizeMB,@CompressionRatio AS CompressionRatio,
        @HasBackupChecksums AS HasBackupChecksums,@IsDamaged AS IsDamaged,@RecoveryModel AS RecoveryModel,
        @FirstLsn AS FirstLsn,@LastLsn AS LastLsn,@DatabaseBackupLsn AS DatabaseBackupLsn,@CheckpointLsn AS CheckpointLsn
) AS src
ON tgt.InstanceId=src.InstanceId AND tgt.BackupSetId=src.BackupSetId
WHEN MATCHED THEN UPDATE SET
    ScanRunId=src.ScanRunId,DatabaseName=src.DatabaseName,BackupType=src.BackupType,
    BackupTypeDescription=src.BackupTypeDescription,IsCopyOnly=src.IsCopyOnly,
    BackupStartDate=src.BackupStartDate,BackupFinishDate=src.BackupFinishDate,
    DurationSeconds=src.DurationSeconds,BackupSizeMB=src.BackupSizeMB,
    CompressedBackupSizeMB=src.CompressedBackupSizeMB,CompressionRatio=src.CompressionRatio,
    HasBackupChecksums=src.HasBackupChecksums,IsDamaged=src.IsDamaged,RecoveryModel=src.RecoveryModel,
    FirstLsn=src.FirstLsn,LastLsn=src.LastLsn,DatabaseBackupLsn=src.DatabaseBackupLsn,CheckpointLsn=src.CheckpointLsn
WHEN NOT MATCHED THEN INSERT
(
    ScanRunId,InstanceId,DatabaseName,BackupSetId,BackupType,BackupTypeDescription,IsCopyOnly,
    BackupStartDate,BackupFinishDate,DurationSeconds,BackupSizeMB,CompressedBackupSizeMB,
    CompressionRatio,HasBackupChecksums,IsDamaged,RecoveryModel,FirstLsn,LastLsn,DatabaseBackupLsn,CheckpointLsn
)
VALUES
(
    src.ScanRunId,src.InstanceId,src.DatabaseName,src.BackupSetId,src.BackupType,src.BackupTypeDescription,src.IsCopyOnly,
    src.BackupStartDate,src.BackupFinishDate,src.DurationSeconds,src.BackupSizeMB,src.CompressedBackupSizeMB,
    src.CompressionRatio,src.HasBackupChecksums,src.IsDamaged,src.RecoveryModel,src.FirstLsn,src.LastLsn,src.DatabaseBackupLsn,src.CheckpointLsn
)
OUTPUT inserted.BackupHistoryId;
"@ @{
                    ScanRunId=$scanRunId; InstanceId=$instanceId; DatabaseName=$h.DatabaseName; BackupSetId=$h.BackupSetId
                    BackupType=$h.BackupType; BackupTypeDescription=$h.BackupTypeDescription; IsCopyOnly=$h.IsCopyOnly
                    BackupStartDate=$h.BackupStartDate; BackupFinishDate=$h.BackupFinishDate; DurationSeconds=$h.DurationSeconds
                    BackupSizeMB=$h.BackupSizeMB; CompressedBackupSizeMB=$h.CompressedBackupSizeMB; CompressionRatio=$h.CompressionRatio
                    HasBackupChecksums=$h.HasBackupChecksums; IsDamaged=$h.IsDamaged; RecoveryModel=$h.RecoveryModel
                    FirstLsn=$h.FirstLsn; LastLsn=$h.LastLsn; DatabaseBackupLsn=$h.DatabaseBackupLsn; CheckpointLsn=$h.CheckpointLsn
                }

                Exec-NonQuery $repo "DELETE FROM [backup].BackupFile WHERE BackupHistoryId=@Id;" @{Id=$backupHistoryId} | Out-Null

                $files = Get-DataTable $target @"
SELECT
    logical_device_name AS LogicalDeviceName,
    physical_device_name AS PhysicalDeviceName,
    device_type AS DeviceType,
    family_sequence_number AS FamilySequenceNumber,
    mirror AS Mirror
FROM dbo.backupmediafamily
WHERE media_set_id =
(
    SELECT media_set_id FROM dbo.backupset WHERE backup_set_id=@BackupSetId
);
"@ @{BackupSetId=$h.BackupSetId}

                foreach($f in $files.Rows){
                    Exec-NonQuery $repo @"
INSERT [backup].BackupFile
(
    BackupHistoryId,LogicalDeviceName,PhysicalDeviceName,DeviceType,FamilySequenceNumber,Mirror
)
VALUES
(
    @BackupHistoryId,@LogicalDeviceName,@PhysicalDeviceName,@DeviceType,@FamilySequenceNumber,@Mirror
);
"@ @{
                        BackupHistoryId=$backupHistoryId; LogicalDeviceName=$f.LogicalDeviceName; PhysicalDeviceName=$f.PhysicalDeviceName
                        DeviceType=$f.DeviceType; FamilySequenceNumber=$f.FamilySequenceNumber; Mirror=$f.Mirror
                    } | Out-Null
                }
            }

            $instanceCount++
            $objectCount += $history.Rows.Count
            Write-Host "  OK: $($history.Rows.Count) backup sets"
        }
        catch {
            $errorCount++
            Write-Warning "$server : $($_.Exception.Message)"
        }
        finally {
            if($target){$target.Dispose()}
        }
    }

    $status = if($errorCount -eq 0){'SUCCESS'}else{'PARTIAL'}
    Exec-NonQuery $repo @"
UPDATE dbo.ScanRun
SET ScanFinishedAt=SYSDATETIME(),
    Status=@Status,
    InstanceCount=@InstanceCount,
    ObjectCount=@ObjectCount,
    ErrorCount=@ErrorCount
WHERE ScanRunId=@ScanRunId;
"@ @{Status=$status;InstanceCount=$instanceCount;ObjectCount=$objectCount;ErrorCount=$errorCount;ScanRunId=$scanRunId} | Out-Null

    Write-Host "ScanRunId=$scanRunId Status=$status Instances=$instanceCount BackupSets=$objectCount Errors=$errorCount"
}
catch {
    Exec-NonQuery $repo @"
UPDATE dbo.ScanRun
SET ScanFinishedAt=SYSDATETIME(),Status='FAILED',InstanceCount=@InstanceCount,
    ObjectCount=@ObjectCount,ErrorCount=CASE WHEN @ErrorCount=0 THEN 1 ELSE @ErrorCount END
WHERE ScanRunId=@ScanRunId;
"@ @{InstanceCount=$instanceCount;ObjectCount=$objectCount;ErrorCount=$errorCount;ScanRunId=$scanRunId} | Out-Null
    throw
}
finally {
    $repo.Dispose()
}
