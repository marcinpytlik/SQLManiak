#requires -Version 7.2
<#
 SQLManiak DHC v1.7: source SQL Server -> separate/central SQL repository.
 Does NOT create CSV files or terminate sessions. Original DHC v1.5 SQL is unchanged.
 Use RepositoryConnectionString with a login having only DML rights to dhc tables.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$ServerInstance,
 [Parameter(Mandatory)][string]$RepositoryConnectionString,
 [string]$SqlFile=(Join-Path $PSScriptRoot 'SQLManiak_Daily_Health_Check_v1_5_CSV.sql'),
 [string]$TempDBSqlFile=(Join-Path $PSScriptRoot '02_TempDB_Collect.sql'),
 [string]$CapacitySqlFile=(Join-Path $PSScriptRoot '43_CapacityCollect.sql'),
 [switch]$SkipCapacity,
 [switch]$SkipLinkedServer,
 [string[]]$LinkedServerProbeAllowlist=@(),
 [PSCredential]$SqlCredential,
 [switch]$TrustServerCertificate,
 [switch]$SkipTempDB,
 [int]$QueryTimeout=300,
 [ValidateRange(1,300)][int]$ConnectionTimeout=5,
 [ValidateRange(1,1000)][int]$JsonBatchRows=100
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module SqlServer -ErrorAction Stop
# The SqlServer module uses Microsoft.Data.SqlClient.
Add-Type -AssemblyName Microsoft.Data.SqlClient -ErrorAction Stop
if (-not (Test-Path -LiteralPath $SqlFile -PathType Leaf)) { throw "Missing DHC SQL file: $SqlFile" }
if (-not $SkipTempDB -and -not (Test-Path -LiteralPath $TempDBSqlFile -PathType Leaf)) { throw "Missing TempDB SQL file: $TempDBSqlFile" }
if (-not $SkipCapacity -and -not (Test-Path -LiteralPath $CapacitySqlFile -PathType Leaf)) { throw "Missing Capacity SQL file: $CapacitySqlFile" }

function Get-Tables([object[]]$Results) {
 $list=[System.Collections.Generic.List[System.Data.DataTable]]::new()
 foreach($x in $Results) {
  if($x -is [System.Data.DataSet]) { foreach($t in $x.Tables) { $list.Add($t) } }
  elseif($x -is [System.Data.DataTable]) { $list.Add($x) }
  else { throw "Unexpected Invoke-Sqlcmd result type: $($x.GetType().FullName)" }
 }
 Write-Output -NoEnumerate $list
}
function Test-MainCollectionContract($Tables) {
 # DHC v1.5 CSV + v1.7 XE rewrite: LAB-observed column signatures.
 # Match exact column sets (case insensitive), not row count or ordinal.
 $contract=[ordered]@{
  INSTANCE='Section,SqlServerName,ConnectedInstance,ActiveNode,IsClustered,ProductVersion,ProductLevel,SqlServerStartTime,FromTime,ToTime'
  SERVICES='Section,servicename,status_desc,startup_type_desc,last_startup_time,is_clustered,cluster_nodename'
  ERRORLOG='Section,LogDate,ProcessInfo,Message'
  JOBS_CURRENT='Section,JobName,IsEnabled,IsRunning,RunningSince,LastRunTime,LastRunResult,LastMessage'
  JOBS_STEPS='Section,JobName,step_id,step_name,Status,RunTime,sql_message_id,sql_severity,message'
  DISK_VOLUMES='Section,volume_mount_point,logical_volume_name,TotalGB,FreeGB,FreePercent,TotalBytes,FreeBytes'
  DATABASES_BACKUPS='Section,DatabaseName,state_desc,recovery_model_desc,is_read_only,is_in_standby,LastFull,LastDiff,LastLog'
  TRANSACTION_LOG='Section,DatabaseName,LogSizeMB,UsedPercent'
  BLOCKING='Section,BlockedSessionId,BlockerSessionId,DatabaseName,wait_type,WaitSeconds,status,host_name,program_name,login_name,RunningStatement'
  FILES_AUTOGROWTH='Section,DatabaseName,LogicalFileName,type_desc,AllocatedMB,GrowthSetting,MaxSizeSetting,PhysicalName'
  MISSED_JOBS='Section,JobName,ScheduleName,ExpectedAt'
  SCHEDULE_DIAGNOSTICS='Section,JobName,ScheduleName,Reason'
  HISTORY='Section,Message'
  AUTOGROWTH_EVENTS='Section,DatabaseName,LogicalFileName,FileType,AllocatedMB,GrowthSetting,HistoryStatus,Events24h,GrowthMB24h,LastAutoGrowth,MaxDurationMs24h,EventsInAvailableTrace,PhysicalName'
  LOG_OVERSIZING='Section,DatabaseName,RecoveryModel,DataSizeGB,LogSizeGB,LogToDataRatio,LogUsedPercent,UsedLogMB,FreeLogMB,LogReuseWait,TotalVLF,ActiveVLF,ActiveVLFSizeMB,VLFStatus,Assessment'
  SUMMARY='Section,Severity,Area,ObjectName,Details'
  COUNTS='Section,CriticalAlerts,WarningAlerts,InfoAlerts,SinceTime,UntilTime'
 }
 $observed=@(foreach($t in $Tables){ ($t.Columns | ForEach-Object {$_.ColumnName.ToLowerInvariant()} | Sort-Object) -join ',' })
 foreach($id in $contract.Keys){
  $signature=(($contract[$id].ToLowerInvariant() -split ',') | Sort-Object) -join ','
  $matches=@($observed | Where-Object {$_ -eq $signature}).Count
  if($matches -ne 1){ "Contract v1: $id expected one matching result schema; found $matches." }
 }
 if($Tables.Count -ne $contract.Count){ "Contract v1: expected $($contract.Count) result sets; observed $($Tables.Count)." }
}

function Convert-Row([System.Data.DataRow]$Row) {
 $values=[ordered]@{}
 foreach($c in $Row.Table.Columns) {
  $v=$Row[$c]; if($v -is [DBNull]) { $v=$null }
  elseif($v -is [byte[]]) { $v='0x'+[Convert]::ToHexString($v) }
  elseif($v -is [datetime]) { $v=$v.ToString('yyyy-MM-ddTHH:mm:ss.fff') }
  $values[$c.ColumnName]=$v
 }
 return [pscustomobject]$values
}
function Update-ErrorLogScan([string]$SqlText) {
 # Keep the supplied DHC v1.5 file unchanged. Replace only the known ERRORLOG scan
 # with enumeration of existing non-empty archives, avoiding missing-file errors
 # that can cause a non-catchable severe error from xp_readerrorlog.
 $pattern='(?s)(?<=/\* 2\. ERRORLOG files 0\.\.N: scan archived files too, to handle restarts and cycling \*/\r?\n)CREATE TABLE #ErrorLogRaw.*?END;(?=\r?\n\r?\nSELECT DISTINCT LogDate,ProcessInfo,\[Text\])'
 if(([regex]::Matches($SqlText,$pattern)).Count -ne 1) {
  throw 'DHC ERRORLOG rewrite: expected exactly one known v1.5 ERRORLOG archive loop. Check the source SQL version.'
 }
 $replacement=@'
CREATE TABLE #ErrorLogRaw (LogDate datetime NULL, ProcessInfo nvarchar(100) NULL, [Text] nvarchar(max) NULL);
CREATE TABLE #AvailableErrorLogs (ArchiveNumber int, LogDate datetime, SizeBytes bigint);
CREATE TABLE #ArchiveErrorLogRaw (LogDate datetime NULL, ProcessInfo nvarchar(100) NULL, [Text] nvarchar(max) NULL);
DECLARE @ErrorLogEnumerationFailed bit = 0;
BEGIN TRY
    INSERT INTO #AvailableErrorLogs (ArchiveNumber,LogDate,SizeBytes)
    EXEC master.sys.sp_enumerrorlogs;
END TRY
BEGIN CATCH
    SET @ErrorLogEnumerationFailed = 1;
    INSERT #Alerts VALUES ('WARNING','ERRORLOG','Archive enumeration',ERROR_MESSAGE());
END CATCH;

-- If enumeration itself fails, try only the current ERRORLOG.
IF @ErrorLogEnumerationFailed = 1
    INSERT INTO #AvailableErrorLogs VALUES (0,@Now,1);

DECLARE @LogsToScan TABLE (ArchiveNumber int PRIMARY KEY);
INSERT INTO @LogsToScan (ArchiveNumber)
SELECT TOP (@ErrorLogFilesToScan) ArchiveNumber
FROM #AvailableErrorLogs
WHERE SizeBytes > 0
  AND (
       ArchiveNumber = 0
       OR LogDate >= @Since
       -- Include the archive immediately preceding the 24-hour boundary.
       OR ArchiveNumber = (
           SELECT TOP (1) ArchiveNumber
           FROM #AvailableErrorLogs
           WHERE SizeBytes > 0 AND LogDate < @Since
           ORDER BY LogDate DESC, ArchiveNumber ASC
       )
  )
ORDER BY ArchiveNumber ASC;

DECLARE @LogNumber int;
DECLARE ErrorLogCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT ArchiveNumber FROM @LogsToScan ORDER BY ArchiveNumber;
OPEN ErrorLogCursor;
FETCH NEXT FROM ErrorLogCursor INTO @LogNumber;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        TRUNCATE TABLE #ArchiveErrorLogRaw;
        INSERT INTO #ArchiveErrorLogRaw (LogDate,ProcessInfo,[Text])
        EXEC master.sys.sp_readerrorlog @LogNumber,1;
        INSERT INTO #ErrorLogRaw (LogDate,ProcessInfo,[Text])
        SELECT LogDate,ProcessInfo,[Text]
        FROM #ArchiveErrorLogRaw
        WHERE LogDate >= @Since AND LogDate <= @Now;
    END TRY
    BEGIN CATCH
        INSERT #Alerts VALUES ('WARNING','ERRORLOG',CONCAT('Archive ',@LogNumber),ERROR_MESSAGE());
    END CATCH;
    FETCH NEXT FROM ErrorLogCursor INTO @LogNumber;
END;
CLOSE ErrorLogCursor;
DEALLOCATE ErrorLogCursor;
'@
 return [regex]::Replace($SqlText,$pattern,[System.Text.RegularExpressions.MatchEvaluator]{param($m) $replacement})
}


function Update-AutogrowthScan([string]$SqlText) {
 # Replace ONLY the known original v1.5 section 12C in memory.
 # Leave the original file unchanged, with the same result shape / alert thresholds.
 $pattern='(?s)/\* 12C\. ACTUAL AUTOGROWTH EVENTS .*?(?=/\* 12D\. LOG OVERSIZING ANALYSIS)'
 if(([regex]::Matches($SqlText,$pattern)).Count -ne 1) {
  throw 'DHC XE autogrowth rewrite: expected exactly one known v1.5 section 12C.'
 }
 $replacement=@'
/* 12C. ACTUAL AUTOGROWTH EVENTS - SQLManiak_Autogrowth Extended Events.
   Uses SQL Server UTC XE timestamps, read-only file access and #CurrentFiles.
   AVAILABLE_PARTIAL is deliberate: rolling XEL files cannot prove full 24h coverage.
   A zero count with partial history is not evidence of zero autogrowth.
*/
BEGIN TRY
    DECLARE @XeAutoNowUTC datetime2(7) = SYSUTCDATETIME();
    DECLARE @XeAutoSinceUTC datetime2(7) = DATEADD(HOUR,-24,@XeAutoNowUTC);
    DECLARE @AutoGrowthHistoryStatus varchar(32) = 'UNAVAILABLE';
    DECLARE @XeAutoFileName nvarchar(4000) = NULL;
    DECLARE @XeAutoPattern nvarchar(4000) = NULL;

    CREATE TABLE #XeAutoEvents
    (
        DatabaseID int NOT NULL,
        FileID int NOT NULL,
        EventUTC datetime2(7) NOT NULL,
        SizeChangeKB bigint NOT NULL,
        DurationMicroseconds bigint NULL
    );

    -- A live session and a configured event_file target are required.
    IF EXISTS
    (
        SELECT 1 FROM sys.dm_xe_sessions
        WHERE name = N'SQLManiak_Autogrowth'
    )
    BEGIN
        BEGIN TRY
            SELECT TOP (1) @XeAutoFileName = CONVERT(nvarchar(4000),f.value)
            FROM sys.server_event_sessions s
            JOIN sys.server_event_session_targets t
              ON t.event_session_id=s.event_session_id AND t.name=N'event_file'
            JOIN sys.server_event_session_fields f
              ON f.event_session_id=s.event_session_id
             AND f.object_id=t.target_id AND f.name=N'filename'
            WHERE s.name = N'SQLManiak_Autogrowth';

            IF @XeAutoFileName IS NULL
               OR RIGHT(LOWER(@XeAutoFileName),4) <> N'.xel'
                THROW 51940, 'XE event_file target filename not found.', 1;

            SET @XeAutoPattern =
                LEFT(@XeAutoFileName,LEN(@XeAutoFileName)-4) + N'*.xel';

            -- Materialize first: lab verified that predicate pushdown on
            -- timestamp_utc directly in fn_xe_file_target_read_file can
            -- unexpectedly return an empty set on tested SQL build.
            CREATE TABLE #XeAutoRaw
            (
                EventUTC datetime2(7) NOT NULL,
                EventXml xml NOT NULL
            );
            INSERT #XeAutoRaw(EventUTC,EventXml)
            SELECT timestamp_utc,CAST(event_data AS xml)
            FROM sys.fn_xe_file_target_read_file(
                 @XeAutoPattern,NULL,NULL,NULL)
            WHERE object_name=N'database_file_size_change';

            INSERT #XeAutoEvents
                (DatabaseID,FileID,EventUTC,SizeChangeKB,DurationMicroseconds)
            SELECT
                r.EventXml.value('(/event/data[@name="database_id"]/value)[1]','int'),
                r.EventXml.value('(/event/data[@name="file_id"]/value)[1]','int'),
                r.EventUTC,
                r.EventXml.value('(/event/data[@name="size_change_kb"]/value)[1]','bigint'),
                r.EventXml.value('(/event/data[@name="duration"]/value)[1]','bigint')
            FROM #XeAutoRaw AS r
            WHERE r.EventXml.value('(/event/data[@name="is_automatic"]/value)[1]','bit')=1
              AND r.EventXml.value('(/event/data[@name="size_change_kb"]/value)[1]','bigint')>0;

            SET @AutoGrowthHistoryStatus = 'AVAILABLE_PARTIAL';
        END TRY
        BEGIN CATCH
            INSERT #Alerts VALUES('WARNING','AUTOGROWTH',NULL,
                CONCAT('XE autogrowth read unavailable: ',ERROR_MESSAGE()));
        END CATCH;
    END
    ELSE
        INSERT #Alerts VALUES('WARNING','AUTOGROWTH',NULL,
            'SQLManiak_Autogrowth XE session is not running; history unavailable.');

    ;WITH EventAgg AS
    (
        SELECT DatabaseID,FileID,
               COUNT_BIG(*) AS EventsInAvailableTrace,
               SUM(CASE WHEN EventUTC BETWEEN @XeAutoSinceUTC AND @XeAutoNowUTC
                    THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS Events24h,
               MAX(EventUTC) AS LastAutoGrowth,
               SUM(CASE WHEN EventUTC BETWEEN @XeAutoSinceUTC AND @XeAutoNowUTC
                    THEN CONVERT(decimal(19,2),SizeChangeKB/1024.0)
                    ELSE CONVERT(decimal(19,2),0) END) AS GrowthMB24h,
               MAX(CASE WHEN EventUTC BETWEEN @XeAutoSinceUTC AND @XeAutoNowUTC
                    THEN CONVERT(decimal(19,2),DurationMicroseconds/1000.0)
                    END) AS MaxDurationMs24h
        FROM #XeAutoEvents
        GROUP BY DatabaseID,FileID
    )
    SELECT f.database_id,f.file_id,f.DatabaseName,f.LogicalFileName,
           f.type_desc AS FileType,f.PhysicalName,f.AllocatedMB,f.GrowthSetting,
           @AutoGrowthHistoryStatus AS HistoryStatus,
           CASE WHEN @AutoGrowthHistoryStatus<>'AVAILABLE_PARTIAL' THEN NULL
                ELSE ISNULL(a.Events24h,CONVERT(bigint,0)) END AS Events24h,
           CASE WHEN @AutoGrowthHistoryStatus<>'AVAILABLE_PARTIAL' THEN NULL
                ELSE ISNULL(a.GrowthMB24h,CONVERT(decimal(19,2),0)) END AS GrowthMB24h,
           CASE WHEN @AutoGrowthHistoryStatus<>'AVAILABLE_PARTIAL' THEN NULL
                ELSE a.LastAutoGrowth END AS LastAutoGrowth,
           CASE WHEN @AutoGrowthHistoryStatus<>'AVAILABLE_PARTIAL' THEN NULL
                ELSE a.MaxDurationMs24h END AS MaxDurationMs24h,
           CASE WHEN @AutoGrowthHistoryStatus<>'AVAILABLE_PARTIAL' THEN NULL
                ELSE ISNULL(a.EventsInAvailableTrace,CONVERT(bigint,0)) END AS EventsInAvailableTrace
    INTO #AutoGrowthReport
    FROM #CurrentFiles AS f
    LEFT JOIN EventAgg AS a
      ON a.DatabaseID=f.database_id AND a.FileID=f.file_id
    WHERE f.type_desc IN ('ROWS','LOG');

    SELECT '12C AUTOGROWTH EVENTS' AS Section,
           DatabaseName,LogicalFileName,FileType,AllocatedMB,GrowthSetting,
           HistoryStatus,Events24h,GrowthMB24h,LastAutoGrowth,MaxDurationMs24h,
           EventsInAvailableTrace,PhysicalName
    FROM #AutoGrowthReport
    ORDER BY Events24h DESC,DatabaseName,LogicalFileName;

    INSERT #Alerts(Severity,Area,ObjectName,Details)
    SELECT CASE WHEN Events24h>=@AutoGrowthFrequentCount*3
                THEN 'CRITICAL' ELSE 'WARNING' END,
           'AUTOGROWTH',CONCAT(DatabaseName,'.',LogicalFileName),
           CONCAT('Frequent autogrowth: ',Events24h,' events in available 24h; ',
                  GrowthMB24h,' MB total; longest ',
                  COALESCE(CONVERT(varchar(40),MaxDurationMs24h),'n/a'),' ms')
    FROM #AutoGrowthReport
    WHERE Events24h>=@AutoGrowthFrequentCount;

    INSERT #Alerts(Severity,Area,ObjectName,Details)
    SELECT 'WARNING','AUTOGROWTH',CONCAT(DatabaseName,'.',LogicalFileName),
           CONCAT('Slow autogrowth: maximum ',MaxDurationMs24h,
                  ' ms in available 24h; events: ',Events24h)
    FROM #AutoGrowthReport
    WHERE MaxDurationMs24h>=@AutoGrowthSlowMs
      AND (Events24h<@AutoGrowthFrequentCount OR Events24h IS NULL);

    INSERT #Alerts(Severity,Area,ObjectName,Details)
    SELECT 'WARNING','AUTOGROWTH',CONCAT(DatabaseName,'.',LogicalFileName),
           CONCAT('High autogrowth volume: ',GrowthMB24h,
                  ' MB in available 24h; events: ',Events24h)
    FROM #AutoGrowthReport
    WHERE GrowthMB24h>=@AutoGrowthGrowthWarningMB
      AND (Events24h<@AutoGrowthFrequentCount OR Events24h IS NULL)
      AND (MaxDurationMs24h<@AutoGrowthSlowMs OR MaxDurationMs24h IS NULL);
END TRY
BEGIN CATCH
    INSERT #Alerts VALUES('WARNING','AUTOGROWTH',NULL,
        CONCAT('XE autogrowth audit failed: ',ERROR_MESSAGE()));
END CATCH;

'@
 return [regex]::Replace($SqlText,$pattern,
    [System.Text.RegularExpressions.MatchEvaluator]{param($m) $replacement})
}

function Update-JobsDependency([string]$SqlText) {
 # Keep v1.5 on disk unchanged. Fail closed for unrecognised SQL versions.
 $rules=@(
  @{
   Pattern='(?m)^(/\* 3\. All SQL Server Agent jobs and recent failures \*/\r?\n)BEGIN TRY'
   Replacement=@'
$1CREATE TABLE #Jobs(
 job_id uniqueidentifier NOT NULL, JobName sysname NOT NULL,
 IsEnabled tinyint NULL, IsRunning int NOT NULL, RunningSince datetime NULL,
 LastRunTime datetime NULL, LastRunStatus int NULL, LastMessage nvarchar(4000) NULL,
 LastRunResult varchar(32) NOT NULL
);
DECLARE @JobsCollectionSucceeded bit=0;
BEGIN TRY
'@
  },
  @{
   Pattern='(?m)^(\s*)SELECT j\.job_id, j\.name AS JobName, j\.enabled AS IsEnabled,'
   Replacement='$1INSERT #Jobs(job_id,JobName,IsEnabled,IsRunning,RunningSince,LastRunTime,LastRunStatus,LastMessage,LastRunResult) SELECT j.job_id, j.name AS JobName, j.enabled AS IsEnabled,'
  },
  @{
   Pattern='(?m)^[ \t]*INTO #Jobs[ \t]*\r?\n'
   Replacement=''
  },
  @{
   Pattern="(?m)^END TRY\r?\nBEGIN CATCH\r?\n[ \t]*INSERT #Alerts VALUES \('WARNING','JOBS',NULL,ERROR_MESSAGE\(\)\);\r?\nEND CATCH;"
   Replacement=@'
    SET @JobsCollectionSucceeded=1;
END TRY
BEGIN CATCH
    INSERT #Alerts VALUES ('WARNING','JOBS',NULL,CONCAT('COLLECTION_FAILED: ',ERROR_MESSAGE()));
END CATCH;
'@
  },
  @{
   Pattern='(?m)^BEGIN TRY\r?\n([ \t]*CREATE TABLE #ScheduleCoverage\()'
   Replacement=@'
BEGIN TRY
    IF @JobsCollectionSucceeded=0
        THROW 51071,'DEPENDENCY_FAILED: JOBS collection unavailable; schedule inference skipped.',1;
$1
'@
  },
  @{
   Pattern="(?m)INSERT #Alerts VALUES \('WARNING','JOB SCHEDULE',NULL,ERROR_MESSAGE\(\)\);"
   Replacement="INSERT #Alerts VALUES ('WARNING','JOB SCHEDULE',NULL,CONCAT('COLLECTION_FAILED: ',ERROR_MESSAGE()));"
  }
 )
 foreach($rule in $rules){
  if(([regex]::Matches($SqlText,$rule.Pattern)).Count -ne 1){
   throw "DHC JOBS dependency rewrite: expected exactly one known anchor: $($rule.Pattern)"
  }
  $SqlText=[regex]::Replace($SqlText,$rule.Pattern,$rule.Replacement)
 }
 return $SqlText
}

function Query-Source([string]$QueryFile,[string]$Prefix='') {
 $args=@{ServerInstance=$ServerInstance;Database='master';QueryTimeout=$QueryTimeout;ConnectionTimeout=$ConnectionTimeout;
         OutputAs='DataSet';ErrorAction='Stop'}
 if ($null -ne $SqlCredential) { $args.Credential=$SqlCredential }
 if ($TrustServerCertificate) { $args.TrustServerCertificate=$true }
 $args.Query=(Get-Content -LiteralPath $QueryFile -Raw -Encoding utf8)
 # Existing DHC has opt-in history; it MUST remain off as all output goes to repository.
 if($QueryFile -eq $SqlFile) {
  $pattern='(?im)^(\s*DECLARE\s+@SaveHistory\s+bit\s*=\s*)[01](\s*;)'
  if(([regex]::Matches($args.Query,$pattern)).Count -ne 1) {
   throw 'Expected exactly one @SaveHistory declaration in DHC v1.5 SQL.'
  }
  $args.Query=[regex]::Replace($args.Query,$pattern,'${1}0${2}')
  $args.Query=Update-ErrorLogScan $args.Query
  $args.Query=Update-AutogrowthScan $args.Query
  $args.Query=Update-JobsDependency $args.Query
 }
 $args.Query=$Prefix+$args.Query
 return @(Invoke-Sqlcmd @args)
}
function Remove-LegacyLocalHistoryNotice([System.Data.DataTable]$Table) {
 # DHC v1.5 emits an INFO notice telling operators to install local history.
 # v1.7 stores history in the central Repository instead.
 # Suppress ONLY this known legacy INFO line in the transported summary;
 # preserve all other INFO/WARNING/CRITICAL rows and original source SQL.
 if(-not ($Table.Columns.Contains('Severity') -and
          $Table.Columns.Contains('Area') -and
          $Table.Columns.Contains('Details'))) { return }
 for($rowIndex=$Table.Rows.Count-1; $rowIndex -ge 0; $rowIndex--) {
  $row=$Table.Rows[$rowIndex]
  if([string]$row['Severity'] -eq 'INFO' -and
     [string]$row['Area'] -eq 'HISTORY' -and
     [string]$row['Details'] -match 'SQLManiak_HealthHistory_Setup\.sql') {
   $Table.Rows.RemoveAt($rowIndex)
  }
 }
}

function Write-Sql([string]$Sql,[hashtable]$P) {
 $cmd=$script:connection.CreateCommand()
 $cmd.Transaction=$script:transaction
 $cmd.CommandTimeout=$QueryTimeout
 $cmd.CommandText=$Sql
 foreach($k in $P.Keys) {
  $v=$P[$k]; if($null -eq $v) { $v=[DBNull]::Value }
  $null=$cmd.Parameters.AddWithValue('@'+$k,$v)
 }
 try { [void]$cmd.ExecuteNonQuery() } catch { throw "Repository SQL write failed. Statement: $Sql. Cause: $($_.Exception.Message)" } finally { $cmd.Dispose() }
}
function Write-Batches([System.Data.DataTable]$Table,[int]$Index,[string]$Name) {
 $cols=@($Table.Columns | ForEach-Object { $_.ColumnName })
 $colsJson=ConvertTo-Json -InputObject $cols -Compress -Depth 6
 $number=0
 $slice=[System.Collections.Generic.List[object]]::new()
 # Zero-row result sets are also stored, including schema/column names.
 foreach($r in $Table.Rows) {
  $slice.Add((Convert-Row $r))
  if($slice.Count -ge $JsonBatchRows) {
   $number++; Save-Batch $Index $number $Name $colsJson $slice
   $slice.Clear()
  }
 }
 if($slice.Count -gt 0 -or $number -eq 0) {
  $number++; Save-Batch $Index $number $Name $colsJson $slice
 }
 $script:storedResultSets++
}
function Save-Batch([int]$Index,[int]$BatchNo,[string]$Name,[string]$ColsJson,$Slice) {
 $json=ConvertTo-Json -InputObject @($Slice.ToArray()) -Compress -Depth 6
 Write-Sql 'INSERT dhc.ResultBatch(RunId,ResultIndex,BatchNo,SectionName,[RowCount],ColumnNamesJson,RowsJson) VALUES (@RunId,@ResultIndex,@BatchNo,@SectionName,@RowCount,@ColumnNamesJson,@RowsJson)' @{
  RunId=$runId;ResultIndex=$Index;BatchNo=$BatchNo;SectionName=$Name;
  RowCount=[int]$Slice.Count;ColumnNamesJson=$ColsJson;RowsJson=$json
 }
}
function Add-Alert([string]$Severity,[string]$Area,[string]$ObjectName,[string]$Details) {
 Write-Sql 'INSERT dhc.Alert(RunId,Severity,Area,ObjectName,Details) VALUES(@RunId,@Severity,@Area,@ObjectName,@Details)' @{
 RunId=$runId;Severity=$Severity;Area=$Area;ObjectName=$ObjectName;Details=$Details.Substring(0,[Math]::Min(2000,$Details.Length)) }
 if($Severity -eq 'CRITICAL') { $script:critical++ } else { $script:warnings++ }
}
function Test-RepositorySchema {
 $required=[ordered]@{'dhc.Run'='01_Repository.sql';'dhc.ResultBatch'='01_Repository.sql';'dhc.Alert'='01_Repository.sql'}
 if(-not $SkipCapacity){$required['dhc.CapacityFileSample']='42_CapacityRepository.sql';$required['dhc.CapacityLogSample']='42_CapacityRepository.sql'}
 if(-not $SkipTempDB){foreach($n in @('dhc.TempDBSnapshot','dhc.TempDBFile','dhc.TempDBSession')){$required[$n]='01_Repository.sql'}}
 $cmd=$connection.CreateCommand()
 try {
  $cmd.CommandTimeout=$QueryTimeout
  $cmd.CommandText="SELECT OBJECT_ID(@name,N'U')"
  [void]$cmd.Parameters.Add('@name',[System.Data.SqlDbType]::NVarChar,128)
  $missing=@()
  foreach($n in $required.Keys){
   $cmd.Parameters['@name'].Value=$n
   $id=$cmd.ExecuteScalar()
   if($null -eq $id -or $id -is [DBNull]){$missing+="${n} (migration: $($required[$n]); or metadata permission missing)"}
  }
  if($missing.Count){throw ('Repository schema preflight failed: '+($missing -join '; '))}
 }finally{$cmd.Dispose()}
}
function Number($Value) { if ($Value -is [DBNull] -or $null -eq $Value) { return 0 }; return [double]$Value }
function Is-Null($Value) { return ($Value -is [DBNull] -or $null -eq $Value) }

$runId=[guid]::NewGuid();$started=[datetime]::UtcNow
$critical=0;$warnings=0;$totalRows=[long]0;$status='COMPLETE';$tempdbError=$null;$moduleErrors=[System.Collections.Generic.List[string]]::new();$storedResultSets=0
$connection=[Microsoft.Data.SqlClient.SqlConnection]::new($RepositoryConnectionString)
$transaction=$null
try {
 # Fail early if the repository does not exist or DML permissions are missing.
 $connection.Open();Test-RepositorySchema;$transaction=$connection.BeginTransaction()
 Write-Sql 'INSERT dhc.Run(RunId,ServerInstance,StartedUTC,Status) VALUES(@RunId,@ServerInstance,@StartedUTC,@Status)' @{
 RunId=$runId;ServerInstance=$ServerInstance;StartedUTC=$started;Status='RUNNING'}

 $mainTables=Get-Tables (Query-Source $SqlFile)
 foreach($table in $mainTables) { Remove-LegacyLocalHistoryNotice $table }
 $i=0
 foreach($t in $mainTables) {
  $i++
  $section="ResultSet_$i"
  if($t.Columns.Contains('Section') -and $t.Rows.Count -gt 0) {
   $candidate=[string]$t.Rows[0]['Section'];if($candidate.Trim()){$section=$candidate.Trim()}
  }
  Write-Batches $t $i $section
  $totalRows+=$t.Rows.Count
 }
 $summary=@($mainTables | Where-Object { $_.Columns.Contains('Section') -and $_.Columns.Contains('Severity') -and $_.Columns.Contains('Area') -and $_.Columns.Contains('Details') })
 foreach($issue in @(Test-MainCollectionContract $mainTables)){
  $status='PARTIAL';$moduleErrors.Add('Main SQL: '+$issue)
  Add-Alert 'WARNING' 'COLLECTION CONTRACT' 'Main SQL' $issue
 }
 if($summary.Count -ne 1){
  $status='PARTIAL';$message="Expected one DHC summary result set, found $($summary.Count)."
  $moduleErrors.Add('Main SQL: '+$message)
  Add-Alert 'WARNING' 'COLLECTION CONTRACT' 'SUMMARY' $message
 }
 foreach($summaryTable in $summary){
 foreach($row in $summaryTable.Rows) {
  $sev=[string]$row['Severity'];if($sev -notin @('CRITICAL','WARNING')){continue}
  Add-Alert $sev ([string]$row['Area']) $(if($row.IsNull('ObjectName')){''}else{[string]$row['ObjectName']}) ([string]$row['Details'])
  if([string]$row['Details'] -match '(?i)COLLECTION_FAILED:|DEPENDENCY_FAILED:|permission was denied|permission denied|access is denied|does not have permission|not authorized|odmowa dostępu|odmówiono uprawnień'){
   $status='PARTIAL'
   $moduleErrors.Add("Main SQL: collection failure or possible access denial in $($row['Area']); see alerts.")
   Add-Alert 'WARNING' 'COLLECTION CONTRACT' ([string]$row['Area']) 'Collection failure or possible permission denial reported by legacy collector; review original alert.'
  }
 }
 }

 # Optional capacity module: same run / transaction, isolated using a savepoint.
 # Database/file data are read-only at source. Partial failures are persisted as warnings.
 if(-not $SkipCapacity) {
  $savedRows=$totalRows;$savedWarnings=$warnings;$savedCritical=$critical;$savedSets=$storedResultSets
  $transaction.Save('BeforeCapacity')
  try {
   $capTables=Get-Tables (Query-Source $CapacitySqlFile)
   if($capTables.Count -ne 3) { throw 'Capacity collector must return FILES, LOGS and ERRORS (3 result sets).' }
   $expected=@('CAPACITY_FILES','CAPACITY_LOGS','CAPACITY_ERRORS')
   for($k=0;$k -lt 3;$k++) {
    if(-not $capTables[$k].Columns.Contains('Section')) { throw "Capacity result $k missing Section." }
    if($capTables[$k].Rows.Count -gt 0 -and [string]$capTables[$k].Rows[0]['Section'] -ne $expected[$k]) {
     throw "Unexpected capacity result $k."
    }
    Write-Batches $capTables[$k] (200+$k) $expected[$k]
    $totalRows+=$capTables[$k].Rows.Count
   }
   $fileCols=@('RunId','DatabaseName','DatabaseId','FileId','FileType','FilegroupName','LogicalFileName',
    'PhysicalName','VolumeMountPoint','AllocatedGB','UsedGB','InternalFreeGB','VolumeTotalGB',
    'VolumeFreeGB','MaxSizeGB','MaxSizeKind','GrowthMB','IsPercentGrowth','IsGrowthEnabled')
   $fileSQL='INSERT dhc.CapacityFileSample('+($fileCols -join ',')+') VALUES('+
    (($fileCols|ForEach-Object {'@'+$_}) -join ',')+')'
   foreach($r in $capTables[0].Rows) {
    $p=@{RunId=$runId}
    foreach($c in $fileCols) {
     if($c -eq 'RunId') {continue}
     $v=$r[$c];$p[$c]=if($v -is [DBNull]){$null}else{$v}
    }
    Write-Sql $fileSQL $p
    if(-not $r.IsNull('InternalFreeGB') -and [double]$r['AllocatedGB'] -gt 0) {
     $pct=100*[double]$r['InternalFreeGB']/[double]$r['AllocatedGB']
     if($pct -lt 5) {
      Add-Alert 'WARNING' 'DATA FILE' ("$($r['DatabaseName']).$($r['LogicalFileName'])") ("Low internal free: {0:N2}% - evaluate filegroup headroom." -f $pct)
     }
    }
   }
   $logCols=@('RunId','DatabaseName','DatabaseId','AllocatedLogGB','UsedLogGB',
     'UsedLogPct','LogReuseWait','RecoveryModel')
   $logSQL='INSERT dhc.CapacityLogSample('+($logCols -join ',')+') VALUES('+
    (($logCols|ForEach-Object {'@'+$_}) -join ',')+')'
   foreach($r in $capTables[1].Rows) {
    $p=@{RunId=$runId}
    foreach($c in $logCols) {
     if($c -eq 'RunId') {continue}
     $v=$r[$c];$p[$c]=if($v -is [DBNull]){$null}else{$v}
    }
    Write-Sql $logSQL $p
    if(-not $r.IsNull('UsedLogPct') -and [double]$r['UsedLogPct'] -ge 85) {
     Add-Alert $(if([double]$r['UsedLogPct'] -ge 95){'CRITICAL'}else{'WARNING'}) 'LOG CAPACITY' ([string]$r['DatabaseName']) (
       "Log usage $($r['UsedLogPct'])%; reuse wait: $($r['LogReuseWait']).")
    }
   }
   if($capTables[2].Rows.Count -gt 0) { $status='PARTIAL';$moduleErrors.Add("Capacity: $($capTables[2].Rows.Count) collection errors; see alerts.") }
   foreach($r in $capTables[2].Rows) {
    Add-Alert 'WARNING' 'CAPACITY COLLECTION' ([string]$r['DatabaseName']) ([string]$r['Details'])
   }
  }
  catch {
   $status='PARTIAL'
   $capacityError=$_.Exception.Message;$moduleErrors.Add('Capacity: '+$capacityError)
   $transaction.Rollback('BeforeCapacity')
   $totalRows=$savedRows;$warnings=$savedWarnings;$critical=$savedCritical;$storedResultSets=$savedSets
   Add-Alert 'WARNING' 'CAPACITY COLLECTION' 'module' ('Capacity module failed: '+$capacityError)
  }
 }


 # Linked server history uses the existing JSON batches and retention.
 if(-not $SkipLinkedServer) {
  $savedRows=$totalRows;$savedWarnings=$warnings;$savedCritical=$critical;$savedSets=$storedResultSets
  $transaction.Save('BeforeLinkedServer')
  try {
   $ls=Get-Tables (Query-Source (Join-Path $PSScriptRoot '47_LinkedServerCollect.sql'))
   $names=@('LINKED_SERVER_CONFIGURATION','LINKED_SERVER_LOGIN_MAPPING','LINKED_SERVER_METADATA_STATUS')
   if($ls.Count -ne 3){throw 'Unexpected linked server result set count.'}
   for($k=0;$k -lt 3;$k++){
    if(-not $ls[$k].Columns.Contains('Section')){throw 'Linked server result missing Section.'}
    Write-Batches $ls[$k] (300+$k) $names[$k]
    $totalRows+=$ls[$k].Rows.Count
   }
   # Reuse existing ERRORLOG rows; evidence is not attribution to linked servers.
   $events=[System.Data.DataTable]::new()
   foreach($col in @('Section','LogDate','ProcessInfo','Text')){[void]$events.Columns.Add($col)}
   foreach($t in $mainTables){
    if($t.Columns.Contains('LogDate') -and $t.Columns.Contains('ProcessInfo') -and ($t.Columns.Contains('Text') -or $t.Columns.Contains('Message'))){
      $messageColumn=if($t.Columns.Contains('Text')){'Text'}else{'Message'}
     foreach($row in $t.Rows){
      if([string]$row[$messageColumn] -match 'ANONYMOUS LOGON'){
       [void]$events.Rows.Add('LINKED_SERVER_AUTH_EVENTS',[string]$row['LogDate'],[string]$row['ProcessInfo'],[string]$row[$messageColumn])
      }
     }
    }
   }
   Write-Batches $events 303 'LINKED_SERVER_AUTH_EVENTS'
   $totalRows+=$events.Rows.Count
   if($events.Rows.Count -gt 0){Add-Alert 'WARNING' 'LINKED SERVER AUTH' 'ANONYMOUS LOGON' 'Anonymous logon evidence in collected ERRORLOG; origin not established.'}
   $probeIndex=310
   foreach($name in ($LinkedServerProbeAllowlist | Select-Object -Unique)){
    if([string]::IsNullOrWhiteSpace($name) -or $name.Length -gt 128){throw 'Invalid linked server allowlist name.'}
    $prefix="DECLARE @ProbeName sysname=N'"+$name.Replace("'","''")+"';"+[Environment]::NewLine
    $probe=Get-Tables (Query-Source (Join-Path $PSScriptRoot '48_LinkedServerConnectivity.sql') $prefix)
    if($probe.Count -ne 1 -or $probe[0].Rows.Count -ne 1){throw 'Unexpected linked server probe output.'}
    Write-Batches $probe[0] $probeIndex 'LINKED_SERVER_CONNECTIVITY'
    $probeIndex++;$totalRows++
    $row=$probe[0].Rows[0]
    if([string]$row['ProbeStatus'] -eq 'FAILED'){Add-Alert 'WARNING' 'LINKED SERVER CONNECTIVITY' $name ([string]$row['Details'])}
   }
  } catch {
   $message=$_.Exception.Message;$moduleErrors.Add('Linked Server: '+$message)
   $transaction.Rollback('BeforeLinkedServer')
   $totalRows=$savedRows;$warnings=$savedWarnings;$critical=$savedCritical;$storedResultSets=$savedSets
   $status='PARTIAL'
   Add-Alert 'WARNING' 'LINKED SERVER COLLECTION' 'module' $message
  }
 }

 if(-not $SkipTempDB) {
  $savedRows=$totalRows;$savedWarnings=$warnings;$savedCritical=$critical;$savedSets=$storedResultSets
  $transaction.Save('BeforeTempDB')
  try {
   $tempTables=Get-Tables (Query-Source $TempDBSqlFile)
   if($tempTables.Count -ne 3 -or $tempTables[0].Rows.Count -ne 1) { throw 'TempDB check must return overview, sessions, files (3 result sets).' }
   $j=0
   foreach($t in $tempTables) { $j++;Write-Batches $t (100+$j) @('TEMPDB_OVERVIEW','TEMPDB_SESSIONS','TEMPDB_FILES')[$j-1];$totalRows+=$t.Rows.Count }
   $o=$tempTables[0].Rows[0]
   $d=@{RunId=$runId}
   foreach($column in $tempTables[0].Columns) {
    $name=$column.ColumnName
    if($name -in @('Section','SampleUTC')) {continue}
    $v=$o[$name];if($v -is [DBNull]){$v=$null};$d[$name]=$v
   }
   $d.SampleUTC=([datetime]$o['SampleUTC'])
   $properties=@('RunId','SampleUTC','TotalDataMB','UsedDataMB','FreeDataMB','DataFreePct','UserObjectsMB','InternalObjectsMB','VersionStoreMB','VersionStoreShareUsedPct','TotalLogMB','UsedLogMB','LogFreePct','MinDriveFreePct','AnyFileCannotGrow','PercentGrowthFileCount','DataFileCount','LogFileCount','ActiveVersioningTransactions','OldestVersioningSeconds','TempDBLogReuseWait')
   $columns=$properties -join ',';$parameters=($properties | ForEach-Object {'@'+$_}) -join ','
   Write-Sql "INSERT dhc.TempDBSnapshot($columns) VALUES($parameters)" $d
   foreach($r in $tempTables[1].Rows) {
    $obj=Convert-Row $r;$json=ConvertTo-Json -InputObject $obj -Compress -Depth 6
    Write-Sql 'INSERT dhc.TempDBSession(RunId,SessionId,RequestId,LoginName,SessionAttributedMB,VersioningSeconds,JsonRow) VALUES (@RunId,@SessionId,@RequestId,@LoginName,@SessionAttributedMB,@VersioningSeconds,@JsonRow)' @{
     RunId=$runId;SessionId=[int]$r['session_id'];RequestId=[int]$r['RequestId'];
     LoginName=$(if($r.IsNull('login_name')){$null}else{[string]$r['login_name']});
     SessionAttributedMB=$(if($r.IsNull('SessionAttributedMB')){$null}else{$r['SessionAttributedMB']});
     VersioningSeconds=$(if($r.IsNull('VersioningSeconds')){$null}else{$r['VersioningSeconds']});JsonRow=$json
    }
   }
   foreach($r in $tempTables[2].Rows) {
    $obj=Convert-Row $r;$json=ConvertTo-Json -InputObject $obj -Compress -Depth 6
    $p=@{RunId=$runId;JsonRow=$json}
    foreach($k in @('FileId','FileType','FileName','VolumeMountPoint','SizeMB','MaxSizeMB','GrowthMB','IsPercentGrowth','NextGrowthMB','NextGrowthWillFit','AvailableVolumeMB')) {
      $v=$r[$k];if($v -is [DBNull]){$v=$null};$p[$k]=$v
    }
    Write-Sql 'INSERT dhc.TempDBFile(RunId,FileId,FileType,FileName,VolumeMountPoint,SizeMB,MaxSizeMB,GrowthMB,IsPercentGrowth,NextGrowthMB,NextGrowthWillFit,AvailableVolumeMB,JsonRow) VALUES(@RunId,@FileId,@FileType,@FileName,@VolumeMountPoint,@SizeMB,@MaxSizeMB,@GrowthMB,@IsPercentGrowth,@NextGrowthMB,@NextGrowthWillFit,@AvailableVolumeMB,@JsonRow)' $p
   }
   $dataFree=Number $o['DataFreePct'];$logFree=Number $o['LogFreePct']
   if($dataFree -lt 10 -or $logFree -lt 10){Add-Alert 'CRITICAL' 'TEMPDB' 'tempdb' "Data free=$dataFree%; Log free=$logFree%."}
   elseif($dataFree -lt 25 -or $logFree -lt 25){Add-Alert 'WARNING' 'TEMPDB' 'tempdb' "Data free=$dataFree%; Log free=$logFree%."}
   if((Number $o['AnyFileCannotGrow']) -eq 1){Add-Alert 'CRITICAL' 'TEMPDB' 'tempdb' 'One or more files cannot perform configured next autogrowth.'}
   if((Number $o['MinDriveFreePct']) -lt 10){Add-Alert 'CRITICAL' 'TEMPDB' 'tempdb' "Lowest free disk space = $($o['MinDriveFreePct'])%."}
   if(-not(Is-Null $o['VersionStoreShareUsedPct']) -and (Number $o['VersionStoreShareUsedPct']) -ge 50){Add-Alert 'WARNING' 'TEMPDB' 'VersionStore' "Version Store share = $($o['VersionStoreShareUsedPct'])%; version pages are not attributable to one SPID."}
   if(-not(Is-Null $o['OldestVersioningSeconds']) -and (Number $o['OldestVersioningSeconds']) -ge 3600){Add-Alert 'WARNING' 'TEMPDB' 'VersionStore' "Oldest versioning transaction = $($o['OldestVersioningSeconds']) seconds."}
   if((Number $o['LogFileCount']) -gt 1 -or (Number $o['PercentGrowthFileCount']) -gt 0){Add-Alert 'WARNING' 'TEMPDB' 'tempdb' "Log files=$($o['LogFileCount']); percent-growth files=$($o['PercentGrowthFileCount'])."}
  } catch {
   $tempdbError=$_.Exception.Message;$moduleErrors.Add('TempDB: '+$tempdbError);$status='PARTIAL'
   $transaction.Rollback('BeforeTempDB')
   $totalRows=$savedRows;$warnings=$savedWarnings;$critical=$savedCritical;$storedResultSets=$savedSets
   Add-Alert 'WARNING' 'TEMPDB' 'tempdb' ('Collector failed: '+$tempdbError)
   # A savepoint ensures no incomplete TempDB details remain after a failed module.
  }
 }
 Write-Sql 'UPDATE dhc.Run SET FinishedUTC=SYSUTCDATETIME(), Status=@Status, SourceResultSets=@SourceResultSets,SourceRowCount=@SourceRowCount,ErrorText=@ErrorText WHERE RunId=@RunId' @{
  RunId=$runId;Status=$status;SourceResultSets=$mainTables.Count;SourceRowCount=$totalRows;ErrorText=$(if($moduleErrors.Count){$joined=$moduleErrors -join ' | ';$joined.Substring(0,[Math]::Min(2000,$joined.Length))}else{$null}) }
 $transaction.Commit();$transaction=$null
 [pscustomobject]@{RunId=$runId;Source=$ServerInstance;Status=$status;ResultSets=$mainTables.Count;
 SourceResultSets=$mainTables.Count;StoredResultSets=$storedResultSets;ModuleErrors=$moduleErrors.ToArray();RowsStored=$totalRows;CriticalAlerts=$critical;WarningAlerts=$warnings;Repository='SQLManiakHealthHistory'}
} catch {
 if($null -ne $transaction){try{$transaction.Rollback()}catch{}};
 throw "DHC v1.7 run not committed to repository: $($_.Exception.Message)"
} finally { if($null -ne $transaction){$transaction.Dispose()};$connection.Dispose() }
