[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ServerListPath,
    [Parameter(Mandatory)][string]$RepositoryServerInstance,
    [string]$RepositoryDatabase='DBACentralRepository',
    [ValidateSet('Full','Quick','Jobs','Databases','Stage1','Stage2')]
    [string]$CollectionMode='Full',
    [int]$HistoryDays=35,
    [int]$CommandTimeoutSeconds=180,
    [System.Management.Automation.PSCredential]$SourceSqlCredential,
    [System.Management.Automation.PSCredential]$RepositorySqlCredential
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$modulePath = Join-Path `
    $PSScriptRoot `
    'modules\DBACentralRepository.Common\DBACentralRepository.Common.psd1'

Import-Module `
    -Name $modulePath `
    -Force `
    -ErrorAction Stop


function Invoke-Table {
    param(
        [string]$Server,
        [string]$Database,
        [string]$Query,
        [System.Management.Automation.PSCredential]$Credential
    )

    Invoke-DBACentralDataTable `
        -ServerInstance $Server `
        -DatabaseName $Database `
        -Sql $Query `
        -Credential $Credential `
        -CommandTimeoutSeconds $CommandTimeoutSeconds `
        -ApplicationName 'DBACentralRepository v3 Collector'
}

function Invoke-RepoScalar {
    param(
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
        -ApplicationName 'DBACentralRepository v3 Repository Scalar'
}

function Add-Common {
    param(
        [System.Data.DataTable]$Table,
        [long]$ScanRunId,
        [long]$InstanceId,
        [datetime]$CapturedAt
    )

    Add-DBACentralCommonColumns `
        -DataTable $Table `
        -ScanRunId $ScanRunId `
        -InstanceId $InstanceId `
        -CapturedAt $CapturedAt
}

function Add-ScanInstance {
    param(
        [System.Data.DataTable]$Table,
        [long]$ScanRunId,
        [long]$InstanceId
    )

    Add-DBACentralScanIdentityColumns `
        -DataTable $Table `
        -ScanRunId $ScanRunId `
        -InstanceId $InstanceId
}

function Write-Bulk {
    param(
        [System.Data.DataTable]$Table,
        [string]$Destination
    )

    [void](Write-DBACentralBulkCopy `
        -DataTable $Table `
        -DestinationTable $Destination `
        -ServerInstance $RepositoryServerInstance `
        -DatabaseName $RepositoryDatabase `
        -Credential $RepositorySqlCredential `
        -CommandTimeoutSeconds $CommandTimeoutSeconds)
}

$servers=Import-Csv $ServerListPath -Delimiter ';' |
    Where-Object {$_.Enabled -in @('1','true','True')}

$scanRunId=[long](Invoke-RepoScalar @"
DECLARE @Id bigint;
EXEC dbo.usp_StartScan
 @ScanType=@ScanType,@CollectorHost=@CollectorHost,@CollectorUser=@CollectorUser,
 @RepositoryServer=@RepositoryServer,@ScanRunId=@Id OUTPUT;
SELECT @Id;
"@ @{
ScanType=$CollectionMode
CollectorHost=$env:COMPUTERNAME
CollectorUser=[System.Security.Principal.WindowsIdentity]::GetCurrent().Name
RepositoryServer=$RepositoryServerInstance
})

$instanceCount=0
$objectCount=0
$errorCount=0

foreach($s in $servers){
    $capturedAt = [System.DateTime]::Now
    $instanceId=0L
    try{
        Write-Host "Skanowanie $($s.ServerInstance)" -ForegroundColor Cyan

        $info=Invoke-Table $s.ServerInstance master @"
SELECT
CAST(SERVERPROPERTY('MachineName') AS nvarchar(256)) MachineName,
CAST(SERVERPROPERTY('ServerName') AS nvarchar(256)) ServerName,
CAST(SERVERPROPERTY('InstanceName') AS nvarchar(256)) InstanceName,
CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)) ProductVersion,
CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(128)) ProductLevel,
CAST(SERVERPROPERTY('Edition') AS nvarchar(256)) Edition,
CAST(SERVERPROPERTY('EngineEdition') AS int) EngineEdition,
TRY_CONVERT(int,SERVERPROPERTY('ProductMajorVersion')) ProductMajorVersion,
CAST(SERVERPROPERTY('IsClustered') AS bit) IsClustered,
CAST(SERVERPROPERTY('IsHadrEnabled') AS bit) IsHadrEnabled;
"@ $SourceSqlCredential

        $i=$info.Rows[0]
        $instanceId=[long](Invoke-RepoScalar @"
DECLARE @InstanceId bigint;
EXEC dbo.usp_UpsertInstance
 @ServerInstance=@ServerInstance,@EnvironmentCode=@EnvironmentCode,@Description=@Description,
 @MachineName=@MachineName,@ServerName=@ServerName,@InstanceName=@InstanceName,
 @ProductVersion=@ProductVersion,@ProductLevel=@ProductLevel,@Edition=@Edition,
 @EngineEdition=@EngineEdition,@ProductMajorVersion=@ProductMajorVersion,
 @IsClustered=@IsClustered,@IsHadrEnabled=@IsHadrEnabled,
 @ScanRunId=@ScanRunId,@IsReachable=1,@InstanceId=@InstanceId OUTPUT;
SELECT @InstanceId;
"@ @{
ServerInstance=$s.ServerInstance;EnvironmentCode=$s.Environment;Description=$s.Description;
MachineName=$i.MachineName;ServerName=$i.ServerName;InstanceName=$i.InstanceName;
ProductVersion=$i.ProductVersion;ProductLevel=$i.ProductLevel;Edition=$i.Edition;
EngineEdition=$i.EngineEdition;ProductMajorVersion=$i.ProductMajorVersion;
IsClustered=$i.IsClustered;IsHadrEnabled=$i.IsHadrEnabled;ScanRunId=$scanRunId})

        $collectJobs=$s.CollectJobs -eq '1'
        $collectDatabases=$s.CollectDatabases -eq '1'
        $collectBackup=$s.CollectBackup -eq '1'
        $collectCapacity=$s.CollectCapacity -eq '1'
        $collectHA=$s.CollectHA -eq '1'
        $collectMaintenance=$s.CollectMaintenance -eq '1'
        $collectPatch=$s.CollectPatch -eq '1'
        $collectConfig=$s.CollectConfig -eq '1'
        $collectSecurity=$s.CollectSecurity -eq '1'

        if($CollectionMode -eq 'Jobs'){$collectDatabases=$false;$collectBackup=$false;$collectCapacity=$false;$collectHA=$false;$collectMaintenance=$false;$collectPatch=$false;$collectConfig=$false}
        if($CollectionMode -eq 'Databases'){$collectJobs=$false;$collectBackup=$false;$collectCapacity=$false;$collectHA=$false;$collectMaintenance=$false;$collectPatch=$false;$collectConfig=$false;$collectSecurity=$false}
        if($CollectionMode -eq 'Stage1'){$collectJobs=$false;$collectDatabases=$false;$collectPatch=$false;$collectConfig=$false;$collectSecurity=$false}
        if($CollectionMode -eq 'Stage2'){$collectJobs=$false;$collectDatabases=$false;$collectBackup=$false;$collectCapacity=$false;$collectHA=$false;$collectMaintenance=$false}

        if($collectJobs){
            $jobs=Invoke-Table $s.ServerInstance msdb @"
SELECT j.job_id JobId,j.name JobName,c.name CategoryName,SUSER_SNAME(j.owner_sid) OwnerName,
j.description Description,j.enabled IsEnabled,j.start_step_id StartStepId,
j.date_created DateCreated,j.date_modified DateModified,j.notify_level_email NotifyLevelEmail,
o.name OperatorName
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.syscategories c ON c.category_id=j.category_id
LEFT JOIN msdb.dbo.sysoperators o ON o.id=j.notify_email_operator_id;
"@ $SourceSqlCredential
            Add-Common $jobs $scanRunId $instanceId $capturedAt
            Write-Bulk $jobs 'job.JobSnapshot'
            $objectCount+=$jobs.Rows.Count

            $steps=Invoke-Table $s.ServerInstance msdb @"
SELECT j.job_id JobId,j.name JobName,st.step_id StepId,st.step_name StepName,
st.subsystem Subsystem,st.database_name DatabaseName,st.command CommandText,
p.name ProxyName,st.retry_attempts RetryAttempts,st.retry_interval RetryInterval,
st.output_file_name OutputFileName,st.on_success_action OnSuccessAction,
st.on_success_step_id OnSuccessStepId,st.on_fail_action OnFailAction,
st.on_fail_step_id OnFailStepId
FROM msdb.dbo.sysjobsteps st
JOIN msdb.dbo.sysjobs j ON j.job_id=st.job_id
LEFT JOIN msdb.dbo.sysproxies p ON p.proxy_id=st.proxy_id;
"@ $SourceSqlCredential
            Add-Common $steps $scanRunId $instanceId $capturedAt
            Write-Bulk $steps 'job.JobStepSnapshot'

            $schedules=Invoke-Table $s.ServerInstance msdb @"
SELECT j.job_id JobId,j.name JobName,sc.schedule_id ScheduleId,sc.name ScheduleName,
sc.enabled IsEnabled,sc.freq_type FreqType,sc.freq_interval FreqInterval,
sc.freq_subday_type FreqSubdayType,sc.freq_subday_interval FreqSubdayInterval,
sc.freq_relative_interval FreqRelativeInterval,sc.freq_recurrence_factor FreqRecurrenceFactor,
sc.active_start_date ActiveStartDate,sc.active_end_date ActiveEndDate,
sc.active_start_time ActiveStartTime,sc.active_end_time ActiveEndTime,
CASE WHEN js.next_run_date=0 THEN NULL ELSE msdb.dbo.agent_datetime(js.next_run_date,js.next_run_time) END NextRunAt
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobschedules js ON js.job_id=j.job_id
JOIN msdb.dbo.sysschedules sc ON sc.schedule_id=js.schedule_id;
"@ $SourceSqlCredential
            Add-Common $schedules $scanRunId $instanceId $capturedAt
            Write-Bulk $schedules 'job.JobScheduleSnapshot'

            $operators=Invoke-Table $s.ServerInstance msdb @"
SELECT id OperatorId,name OperatorName,enabled IsEnabled,email_address EmailAddress,
pager_address PagerAddress,netsend_address NetsendAddress,
weekday_pager_start_time WeekdayPagerStartTime,weekday_pager_end_time WeekdayPagerEndTime,
saturday_pager_start_time SaturdayPagerStartTime,saturday_pager_end_time SaturdayPagerEndTime,
sunday_pager_start_time SundayPagerStartTime,sunday_pager_end_time SundayPagerEndTime,
pager_days PagerDays
FROM msdb.dbo.sysoperators;
"@ $SourceSqlCredential
            Add-Common $operators $scanRunId $instanceId $capturedAt
            Write-Bulk $operators 'job.OperatorSnapshot'
        }

        if($collectDatabases){
            $dbs=Invoke-Table $s.ServerInstance master @"
WITH S AS
(
 SELECT database_id,
 SUM(CASE WHEN type=0 THEN size END)*8.0/1024 DataSizeMB,
 SUM(CASE WHEN type=1 THEN size END)*8.0/1024 LogSizeMB
 FROM sys.master_files GROUP BY database_id
)
SELECT d.database_id DatabaseId,d.name DatabaseName,d.state_desc StateDesc,
d.user_access_desc UserAccessDesc,d.recovery_model_desc RecoveryModelDesc,
d.compatibility_level CompatibilityLevel,d.collation_name CollationName,
SUSER_SNAME(d.owner_sid) OwnerName,d.create_date CreateDate,
d.page_verify_option_desc PageVerifyOptionDesc,d.is_auto_close_on IsAutoCloseOn,
d.is_auto_shrink_on IsAutoShrinkOn,d.is_auto_create_stats_on IsAutoCreateStatsOn,
d.is_auto_update_stats_on IsAutoUpdateStatsOn,
d.is_auto_update_stats_async_on IsAutoUpdateStatsAsyncOn,
d.is_read_committed_snapshot_on IsReadCommittedSnapshotOn,
d.snapshot_isolation_state_desc SnapshotIsolationStateDesc,
d.is_trustworthy_on IsTrustworthyOn,d.is_db_chaining_on IsDbChainingOn,
d.target_recovery_time_in_seconds TargetRecoveryTimeSeconds,
CAST(CASE WHEN d.is_query_store_on=1 THEN 1 ELSE 0 END AS bit) IsQueryStoreOn,
d.is_encrypted IsEncrypted,
CAST(ISNULL(S.DataSizeMB,0) AS decimal(19,2)) DataSizeMB,
CAST(ISNULL(S.LogSizeMB,0) AS decimal(19,2)) LogSizeMB,
CAST(ISNULL(S.DataSizeMB,0)+ISNULL(S.LogSizeMB,0) AS decimal(19,2)) TotalSizeMB
FROM sys.databases d LEFT JOIN S ON S.database_id=d.database_id;
"@ $SourceSqlCredential
            Add-Common $dbs $scanRunId $instanceId $capturedAt
            Write-Bulk $dbs 'db.DatabaseSnapshot'
            $objectCount+=$dbs.Rows.Count
        }

        if($collectBackup){
            $b=Invoke-Table $s.ServerInstance msdb @"
SELECT bs.backup_set_id BackupSetId,bs.database_name DatabaseName,bs.type BackupType,
CASE bs.type WHEN 'D' THEN N'FULL' WHEN 'I' THEN N'DIFFERENTIAL' WHEN 'L' THEN N'LOG' ELSE bs.type END BackupTypeDescription,
bs.is_copy_only IsCopyOnly,bs.backup_start_date BackupStartDate,bs.backup_finish_date BackupFinishDate,
DATEDIFF(second,bs.backup_start_date,bs.backup_finish_date) DurationSeconds,
CAST(bs.backup_size/1048576.0 AS decimal(19,2)) BackupSizeMB,
CAST(bs.compressed_backup_size/1048576.0 AS decimal(19,2)) CompressedBackupSizeMB,
CAST(CASE WHEN bs.compressed_backup_size>0 THEN bs.backup_size*1.0/bs.compressed_backup_size END AS decimal(19,4)) CompressionRatio,
bs.has_backup_checksums HasBackupChecksums,bs.is_damaged IsDamaged,bs.recovery_model RecoveryModel,
bs.first_lsn FirstLsn,bs.last_lsn LastLsn,bs.database_backup_lsn DatabaseBackupLsn,bs.checkpoint_lsn CheckpointLsn
FROM msdb.dbo.backupset bs
WHERE bs.backup_finish_date>=DATEADD(day,-$HistoryDays,GETDATE());
"@ $SourceSqlCredential
            Add-ScanInstance $b $scanRunId $instanceId
            try{Write-Bulk $b 'backup.BackupHistory'}catch{}
        }

        if($collectCapacity){
            $v=Invoke-Table $s.ServerInstance master @"
SELECT DISTINCT vs.volume_mount_point VolumeMountPoint,vs.logical_volume_name LogicalVolumeName,
vs.file_system_type FileSystemType,CAST(vs.total_bytes/1073741824.0 AS decimal(19,2)) TotalGB,
CAST(vs.available_bytes/1073741824.0 AS decimal(19,2)) AvailableGB,
CAST(vs.available_bytes*100.0/NULLIF(vs.total_bytes,0) AS decimal(9,2)) FreePercent
FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id,mf.file_id) vs;
"@ $SourceSqlCredential
            Add-Common $v $scanRunId $instanceId $capturedAt
            Write-Bulk $v 'capacity.VolumeSnapshot'
        }

        if($collectHA -and [bool]$i.IsHadrEnabled){
            $dr=Invoke-Table $s.ServerInstance master @"
SELECT ag.name GroupName,DB_NAME(drs.database_id) DatabaseName,drs.is_local IsLocal,
sys.fn_hadr_is_primary_replica(DB_NAME(drs.database_id)) IsPrimaryReplica,
drs.synchronization_state_desc SynchronizationStateDesc,
drs.synchronization_health_desc SynchronizationHealthDesc,
drs.database_state_desc DatabaseStateDesc,drs.is_suspended IsSuspended,
drs.suspend_reason_desc SuspendReasonDesc,drs.log_send_queue_size LogSendQueueKB,
drs.redo_queue_size RedoQueueKB,drs.log_send_rate LogSendRateKBs,
drs.redo_rate RedoRateKBs,drs.last_commit_time LastCommitTime
FROM sys.dm_hadr_database_replica_states drs
JOIN sys.availability_groups ag ON ag.group_id=drs.group_id
WHERE drs.is_local=1;
"@ $SourceSqlCredential
            Add-Common $dr $scanRunId $instanceId $capturedAt
            Write-Bulk $dr 'ha.DatabaseReplicaSnapshot'
        }

        if($collectMaintenance){
            $sp=Invoke-Table $s.ServerInstance msdb @"
SELECT database_id DatabaseId,DB_NAME(database_id) DatabaseName,file_id FileId,page_id PageId,
event_type EventType,error_count ErrorCount,last_update_date LastUpdateDate
FROM msdb.dbo.suspect_pages;
"@ $SourceSqlCredential
            Add-Common $sp $scanRunId $instanceId $capturedAt
            Write-Bulk $sp 'maintenance.SuspectPageSnapshot'
        }

        if($collectPatch){
            $pb=[System.Data.DataTable]::new()
            foreach($c in @('ProductVersion','ProductLevel','Edition')){[void]$pb.Columns.Add($c)}
            [void]$pb.Columns.Add('ProductMajorVersion',[int])
            [void]$pb.Columns.Add('ScanRunId',[long])
            [void]$pb.Columns.Add('InstanceId',[long])
            [void]$pb.Columns.Add('CapturedAt',[datetime])
            $r=$pb.NewRow()
            $r.ProductVersion=$i.ProductVersion
            $r.ProductLevel=$i.ProductLevel
            $r.Edition=$i.Edition
            $r.ProductMajorVersion=$i.ProductMajorVersion
            $r.ScanRunId=$scanRunId
            $r.InstanceId=$instanceId
            $r.CapturedAt=$capturedAt
            [void]$pb.Rows.Add($r)
            Write-Bulk $pb 'patch.InstanceBuildHistory'
        }

        if($collectConfig){
            $c=Invoke-Table $s.ServerInstance master @"
SELECT name ConfigurationName,minimum MinimumValue,maximum MaximumValue,
value ConfigValue,value_in_use RunValue,is_dynamic IsDynamic,is_advanced IsAdvanced
FROM sys.configurations;
"@ $SourceSqlCredential
            Add-Common $c $scanRunId $instanceId $capturedAt
            Write-Bulk $c 'config.ServerConfigurationSnapshot'
        }

        if($collectSecurity){
            $p=Invoke-Table $s.ServerInstance master @"
SELECT principal_id PrincipalId,name PrincipalName,type_desc PrincipalTypeDesc,
is_disabled IsDisabled,create_date CreateDate,modify_date ModifyDate,
default_database_name DefaultDatabaseName,is_policy_checked IsPolicyChecked,
is_expiration_checked IsExpirationChecked
FROM sys.sql_logins
UNION ALL
SELECT principal_id,name,type_desc,is_disabled,create_date,modify_date,
default_database_name,NULL,NULL
FROM sys.server_principals WHERE type IN('U','G') AND principal_id>0;
"@ $SourceSqlCredential
            Add-Common $p $scanRunId $instanceId $capturedAt
            Write-Bulk $p 'security.ServerPrincipalSnapshot'

            $roles=Invoke-Table $s.ServerInstance master @"
SELECT rolep.name RoleName,memberp.name MemberName
FROM sys.server_role_members rm
JOIN sys.server_principals rolep ON rolep.principal_id=rm.role_principal_id
JOIN sys.server_principals memberp ON memberp.principal_id=rm.member_principal_id;
"@ $SourceSqlCredential
            Add-Common $roles $scanRunId $instanceId $capturedAt
            Write-Bulk $roles 'security.ServerRoleMembershipSnapshot'

            $proxies=Invoke-Table $s.ServerInstance msdb @"
SELECT p.proxy_id ProxyId,p.name ProxyName,c.name CredentialName,p.enabled IsEnabled,p.description Description
FROM msdb.dbo.sysproxies p
LEFT JOIN sys.credentials c ON c.credential_id=p.credential_id;
"@ $SourceSqlCredential
            Add-Common $proxies $scanRunId $instanceId $capturedAt
            Write-Bulk $proxies 'security.ProxySnapshot'

            $credentials=Invoke-Table $s.ServerInstance master @"
SELECT name CredentialName,credential_identity CredentialIdentity,create_date CreateDate,modify_date ModifyDate
FROM sys.credentials;
"@ $SourceSqlCredential
            Add-Common $credentials $scanRunId $instanceId $capturedAt
            Write-Bulk $credentials 'security.CredentialSnapshot'
        }

        $instanceCount++
    }catch{
        $errorCount++
        Write-Warning "$($s.ServerInstance): $($_.Exception.Message)"
    }
}

$status=if($errorCount -eq 0){'SUCCESS'}else{'COMPLETED_WITH_ERRORS'}

[void](Invoke-RepoScalar @"
EXEC dbo.usp_FinishScan
 @ScanRunId=@ScanRunId,@Status=@Status,@InstanceCount=@InstanceCount,
 @ObjectCount=@ObjectCount,@ErrorCount=@ErrorCount;
SELECT 0;
"@ @{
ScanRunId=$scanRunId;Status=$status;InstanceCount=$instanceCount;
ObjectCount=$objectCount;ErrorCount=$errorCount})

if($CollectionMode -in @('Full','Quick','Jobs')){
    try{
        [void](Invoke-RepoScalar @"
DECLARE @ComplianceRunId bigint;
EXEC audit.usp_RunJobComplianceAudit
 @ScanRunId=@ScanRunId,@ComplianceRunId=@ComplianceRunId OUTPUT;
SELECT @ComplianceRunId;
"@ @{ScanRunId=$scanRunId})
    }catch{
        Write-Warning "Audyt zgodności: $($_.Exception.Message)"
    }
}

Write-Host "Zakończono. ScanRunId=$scanRunId; instancje=$instanceCount; obiekty=$objectCount; błędy=$errorCount" -ForegroundColor Green
