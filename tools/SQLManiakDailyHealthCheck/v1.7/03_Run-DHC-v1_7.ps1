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

function Get-Tables([object[]]$Results) {
 $list=[System.Collections.Generic.List[System.Data.DataTable]]::new()
 foreach($x in $Results) {
  if($x -is [System.Data.DataSet]) { foreach($t in $x.Tables) { $list.Add($t) } }
  elseif($x -is [System.Data.DataTable]) { $list.Add($x) }
  else { throw "Unexpected Invoke-Sqlcmd result type: $($x.GetType().FullName)" }
 }
 Write-Output -NoEnumerate $list
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

function Query-Source([string]$QueryFile) {
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
 }
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
function Number($Value) { if ($Value -is [DBNull] -or $null -eq $Value) { return 0 }; return [double]$Value }
function Is-Null($Value) { return ($Value -is [DBNull] -or $null -eq $Value) }

$runId=[guid]::NewGuid();$started=[datetime]::UtcNow
$critical=0;$warnings=0;$totalRows=[long]0;$status='COMPLETE';$tempdbError=$null
$connection=[Microsoft.Data.SqlClient.SqlConnection]::new($RepositoryConnectionString)
$transaction=$null
try {
 # Fail early if the repository does not exist or DML permissions are missing.
 $connection.Open();$transaction=$connection.BeginTransaction()
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
 if($summary.Count -ne 1) {throw "Expected one DHC summary result set, found $($summary.Count)."}
 foreach($row in $summary[0].Rows) {
  $sev=[string]$row['Severity'];if($sev -notin @('CRITICAL','WARNING')){continue}
  Add-Alert $sev ([string]$row['Area']) $(if($row.IsNull('ObjectName')){''}else{[string]$row['ObjectName']}) ([string]$row['Details'])
 }

 if(-not $SkipTempDB) {
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
   $tempdbError=$_.Exception.Message;$status='PARTIAL'
   $transaction.Rollback('BeforeTempDB')
   Add-Alert 'WARNING' 'TEMPDB' 'tempdb' ('Collector failed: '+$tempdbError)
   # A savepoint ensures no incomplete TempDB details remain after a failed module.
  }
 }
 Write-Sql 'UPDATE dhc.Run SET FinishedUTC=SYSUTCDATETIME(), Status=@Status, SourceResultSets=@SourceResultSets,SourceRowCount=@SourceRowCount,ErrorText=@ErrorText WHERE RunId=@RunId' @{
  RunId=$runId;Status=$status;SourceResultSets=$mainTables.Count;SourceRowCount=$totalRows;ErrorText=$tempdbError }
 $transaction.Commit();$transaction=$null
 [pscustomobject]@{RunId=$runId;Source=$ServerInstance;Status=$status;ResultSets=$mainTables.Count;
 RowsStored=$totalRows;CriticalAlerts=$critical;WarningAlerts=$warnings;Repository='SQLManiakHealthHistory'}
} catch {
 if($null -ne $transaction){try{$transaction.Rollback()}catch{}};
 throw "DHC v1.7 run not committed to repository: $($_.Exception.Message)"
} finally { if($null -ne $transaction){$transaction.Dispose()};$connection.Dispose() }
