#requires -Version 7.0
<#
.SYNOPSIS
  SQLManiak DBACentralRepositoryv4 — inventory collector (phase 1).
.DESCRIPTION
  Read-only inspection of source SQL Server; optional parameterized writes to v4.
  No secrets, SQL Agent step command text or module definitions are collected.
  Dry run is the default. Use -Persist to write snapshots.
  Initial scope: instance, configuration, databases, files, SQL Agent metadata,
  logins, server roles/permissions, DB users/roles/permissions.
  FCI/AG, objects/indexes and remaining inventory categories will follow.
.EXAMPLE
  ./Collect-DBAInventory.ps1 -ConfigPath ../../config/servers.example.json
.EXAMPLE
  ./Collect-DBAInventory.ps1 -ConfigPath ../../config/servers.example.json -Persist
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$ConfigPath,
 [switch]$Persist,
 [System.Management.Automation.PSCredential]$SourceCredential,
 [System.Management.Automation.PSCredential]$RepositoryCredential
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if(-not ('System.Data.SqlClient.SqlConnection' -as [type])) {
 try { Add-Type -AssemblyName System.Data.SqlClient -ErrorAction Stop } catch {
  throw 'System.Data.SqlClient unavailable. Install a supported SQL client library or run with a compatible PowerShell environment.'
 }
}
$cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if(-not $cfg.repository.server -or -not $cfg.sourceServers -or $cfg.sourceServers.Count -eq 0) {
 throw 'Configuration requires repository.server and sourceServers[].'
}
$options = $cfg.options
$encrypt = $true
$trust = $false
$timeout = 120
$systemDbs = $true
$dbSecurity = $true
if($null -ne $options) {
 if($null -ne $options.encrypt) { $encrypt = [bool]$options.encrypt }
 if($null -ne $options.trustServerCertificate) { $trust = [bool]$options.trustServerCertificate }
 if($options.commandTimeoutSeconds) { $timeout = [int]$options.commandTimeoutSeconds }
 if($null -ne $options.includeSystemDatabases) { $systemDbs = [bool]$options.includeSystemDatabases }
 if($null -ne $options.collectDatabaseSecurity) { $dbSecurity = [bool]$options.collectDatabaseSecurity }
}
function Open-Db {
 param([string]$Server,[string]$Database,[System.Management.Automation.PSCredential]$Credential)
 $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new()
 $builder['Data Source']=$Server
 $builder['Initial Catalog']=$Database
 $builder['Application Name']='SQLManiak DBACentralRepositoryv4 Inventory'
 $builder['Connect Timeout']=15
 $builder['Encrypt']=$encrypt
 $builder['TrustServerCertificate']=$trust
 if($null -eq $Credential) { $builder['Integrated Security']=$true }
 else {
  $builder['User ID']=$Credential.UserName
  $builder['Password']=$Credential.GetNetworkCredential().Password
 }
 $cn=[System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
 try { $cn.Open(); return $cn }
 catch { $cn.Dispose(); throw }
}
function Invoke-DbTable {
 param([System.Data.SqlClient.SqlConnection]$Connection,[string]$Sql)
 $cmd=$Connection.CreateCommand()
 $cmd.CommandTimeout=$timeout
 $cmd.CommandText=$Sql
 $adapter=[System.Data.SqlClient.SqlDataAdapter]::new($cmd)
 $dt=[System.Data.DataTable]::new()
 try { [void]$adapter.Fill($dt); return ,$dt }
 finally { $adapter.Dispose(); $cmd.Dispose() }
}
function Invoke-DbCommand {
 param([System.Data.SqlClient.SqlConnection]$Connection,[string]$Sql,[hashtable]$SqlParameters=@{},[switch]$Scalar)
 $cmd=$Connection.CreateCommand()
 $cmd.CommandTimeout=$timeout
 $cmd.CommandText=$Sql
 foreach($key in $SqlParameters.Keys) {
  $value=$SqlParameters[$key]
  if($null -eq $value) { $value=[DBNull]::Value }
  [void]$cmd.Parameters.AddWithValue('@'+$key,$value)
 }
 try {
  if($Scalar) { return $cmd.ExecuteScalar() }
  return $cmd.ExecuteNonQuery()
 } finally { $cmd.Dispose() }
}
function Convert-Row {
 param([System.Data.DataRow]$Row)
 $h=[ordered]@{}
 foreach($c in $Row.Table.Columns) {
  $v=$Row[$c.ColumnName]
  if($v -is [DBNull]) { $v=$null }
  $h[$c.ColumnName]=$v
 }
 return $h
}
function Save-Category {
 param([string]$Category,[System.Data.DataTable]$Table,[string[]]$Keys,[long]$ScanRunId,[System.Data.SqlClient.SqlConnection]$Repository)
 $saved=0
 if($null -eq $Table) { return 0 }
 foreach($row in $Table.Rows) {
  $item=Convert-Row $row
  $parts=@()
  foreach($key in $Keys) { $parts += [string]$item[$key] }
  $entityKey=$parts -join '|'
  if([string]::IsNullOrWhiteSpace($entityKey)) { throw "Empty entity key: $Category" }
  if($entityKey.Length -gt 450) { throw "Entity key too long: $Category" }
  if($Persist) {
   $json=ConvertTo-Json -InputObject $item -Depth 8 -Compress
   [void](Invoke-DbCommand -Connection $Repository -Sql @'
INSERT inventory.InventorySnapshot(ScanRunId,Category,EntityKey,DataJson)
VALUES (@id,@category,@entity,@json);
'@ -SqlParameters @{id=$ScanRunId;category=$Category;entity=$entityKey;json=$json})
  }
  $saved++
 }
 return $saved
}
$queries=[ordered]@{
 INSTANCE=@"
SELECT CAST(@@SERVERNAME AS nvarchar(256)) ServerName,
 CAST(SERVERPROPERTY('MachineName') AS nvarchar(128)) MachineName,
 CAST(SERVERPROPERTY('InstanceName') AS nvarchar(128)) InstanceName,
 CAST(SERVERPROPERTY('Edition') AS nvarchar(256)) Edition,
 CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(64)) ProductVersion,
 CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(64)) ProductLevel,
 CAST(SERVERPROPERTY('ProductUpdateLevel') AS nvarchar(64)) ProductUpdateLevel,
 CAST(SERVERPROPERTY('IsClustered') AS int) IsClustered;
"@
 CONFIGURATION=@"
SELECT name,value_in_use,minimum,maximum,is_dynamic,is_advanced
FROM sys.configurations;
"@
 DATABASE=@"
SELECT database_id,name,state_desc,recovery_model_desc,compatibility_level,
 collation_name,user_access_desc,is_read_only,is_auto_close_on,is_auto_shrink_on,
 is_read_committed_snapshot_on,snapshot_isolation_state_desc,page_verify_option_desc,
 log_reuse_wait_desc,create_date
FROM sys.databases;
"@
 DATABASE_FILE=@"
SELECT DB_NAME(database_id) DatabaseName,file_id,name,type_desc,physical_name,
 size,growth,is_percent_growth,max_size,state_desc
FROM sys.master_files;
"@
 SQL_AGENT_JOB=@"
SELECT CONVERT(nvarchar(36),j.job_id) JobId,j.name,j.enabled,j.description,
 j.start_step_id,j.date_created,j.date_modified,c.name CategoryName,
 SUSER_SNAME(j.owner_sid) OwnerName
FROM msdb.dbo.sysjobs j LEFT JOIN msdb.dbo.syscategories c
 ON j.category_id=c.category_id;
"@
 SQL_AGENT_STEP=@"
SELECT CONVERT(nvarchar(36),job_id) JobId,step_id,step_name,subsystem,
 database_name,proxy_id,on_success_action,on_fail_action,retry_attempts,retry_interval
FROM msdb.dbo.sysjobsteps;
"@
 SQL_AGENT_SCHEDULE=@"
SELECT CONVERT(nvarchar(36),js.job_id) JobId,js.schedule_id,s.name,s.enabled,
 s.freq_type,s.freq_interval,s.freq_subday_type,s.freq_subday_interval,
 s.active_start_date,s.active_start_time,s.active_end_date,s.active_end_time
FROM msdb.dbo.sysjobschedules js
JOIN msdb.dbo.sysschedules s ON s.schedule_id=js.schedule_id;
"@
 LOGIN=@"
SELECT principal_id,name,type_desc,is_disabled,default_database_name,
 create_date,modify_date FROM sys.server_principals
 WHERE type IN ('S','U','G','C','K','E','X');
"@
 SERVER_ROLE=@"
SELECT r.name RoleName,m.name MemberName
FROM sys.server_role_members rm
JOIN sys.server_principals r ON r.principal_id=rm.role_principal_id
JOIN sys.server_principals m ON m.principal_id=rm.member_principal_id;
"@
 SERVER_PERMISSION=@"
SELECT p.class_desc,p.major_id,p.permission_name,p.state_desc,
 grantee.name GranteeName,grantor.name GrantorName
FROM sys.server_permissions p
JOIN sys.server_principals grantee ON grantee.principal_id=p.grantee_principal_id
LEFT JOIN sys.server_principals grantor ON grantor.principal_id=p.grantor_principal_id;
"@
}
$dbQueries=[ordered]@{
 DATABASE_USER=@"
SELECT DB_NAME() DatabaseName,principal_id,name,type_desc,authentication_type_desc,
 default_schema_name,create_date,modify_date
FROM sys.database_principals
WHERE type IN ('S','U','G','E','X','C','K','A');
"@
 DATABASE_ROLE=@"
SELECT DB_NAME() DatabaseName,r.name RoleName,m.name MemberName
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id=rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id=rm.member_principal_id;
"@
 DATABASE_PERMISSION=@"
SELECT DB_NAME() DatabaseName,grantee_principal_id,class_desc,major_id,minor_id,
 permission_name,state_desc,grantor_principal_id
FROM sys.database_permissions;
"@
}
$keyMap=@{
 INSTANCE=@('ServerName');CONFIGURATION=@('name');DATABASE=@('database_id')
 DATABASE_FILE=@('DatabaseName','file_id')
 SQL_AGENT_JOB=@('JobId');SQL_AGENT_STEP=@('JobId','step_id')
 SQL_AGENT_SCHEDULE=@('JobId','schedule_id')
 LOGIN=@('principal_id');SERVER_ROLE=@('RoleName','MemberName')
 SERVER_PERMISSION=@('class_desc','major_id','permission_name','state_desc','GranteeName','GrantorName')
 DATABASE_USER=@('DatabaseName','principal_id')
 DATABASE_ROLE=@('DatabaseName','RoleName','MemberName')
 DATABASE_PERMISSION=@('DatabaseName','grantee_principal_id','class_desc','major_id','minor_id','permission_name','state_desc','grantor_principal_id')
}
. (Join-Path $PSScriptRoot 'Inventory.Extended.ps1')
$extendedServerQueries=Get-ExtendedServerQueries
$extendedDbQueries=Get-ExtendedDatabaseQueries
$extendedKeys=Get-ExtendedKeys
foreach($server in $cfg.sourceServers) {
 $src=$null; $repo=$null; $scanId=0L; $errors=0; $rows=0
 $categoryCounts=@{}; $categoryErrors=@{}
 $serverName=[string]$server.name
 Write-Host "Inventory: $serverName | Persist=$([bool]$Persist)"
 try {
  $src=Open-Db $serverName 'master' $SourceCredential
  if($Persist) {
   $repo=Open-Db ([string]$cfg.repository.server) ([string]$cfg.repository.database) $RepositoryCredential
   $envCode=[string]$server.environment
   $arch=[string]$server.architecture
   if(-not $envCode) { throw 'sourceServers.environment is required in persist mode' }
   if(-not $arch) { $arch='UNKNOWN' }
   $scanId=[long](Invoke-DbCommand -Connection $repo -Sql @'
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @id bigint;
SELECT @id=InstanceId FROM inventory.Instance WITH(UPDLOCK,HOLDLOCK) WHERE ServerInstance=@name;
IF @id IS NULL BEGIN
 INSERT inventory.Instance(ServerInstance,EnvironmentCode,Architecture) VALUES(@name,@env,@arch);
 SET @id=SCOPE_IDENTITY();
END;
INSERT inventory.ScanRun(InstanceId,ScanType,CollectorVersion)
VALUES(@id,'FULL','4.0.0-phase1');
SELECT CONVERT(bigint,SCOPE_IDENTITY());
COMMIT;
'@ -SqlParameters @{name=$serverName;env=$envCode;arch=$arch} -Scalar)
  }
  foreach($category in $queries.Keys) {
   try {
    $table=Invoke-DbTable $src $queries[$category]
    $count=Save-Category $category $table $keyMap[$category] $scanId $repo
    $rows+=$count
    $categoryCounts[$category]=$count
    Write-Host "  $category : $count"
   }
   catch {
    $errors++
    $categoryErrors[$category]=$true
    Write-Warning "$serverName / $category : $($_.Exception.Message)"
    if($Persist) {
     [void](Invoke-DbCommand -Connection $repo -Sql 'INSERT inventory.ScanFinding(ScanRunId,Category,Severity,Message) VALUES(@id,@cat,''ERROR'',@msg)' -SqlParameters @{
      id=$scanId;cat=$category;msg=([string]$_.Exception.Message).Substring(0,[Math]::Min(3900,([string]$_.Exception.Message).Length))
     })
    }
   }
  }
  foreach($category in $extendedServerQueries.Keys) {
   try {
    $table=Invoke-DbTable $src $extendedServerQueries[$category]
    $count=Save-Category $category $table $extendedKeys[$category] $scanId $repo
    $rows+=$count
    $categoryCounts[$category]=$count
    Write-Host "  $category : $count"
   } catch {
    $errors++
    $categoryErrors[$category]=$true
    Write-Warning "$serverName / $category : $($_.Exception.Message)"
    if($Persist) {
     [void](Invoke-DbCommand -Connection $repo -Sql 'INSERT inventory.ScanFinding(ScanRunId,Category,Severity,Message) VALUES(@id,@cat,''ERROR'',@msg)' -SqlParameters @{
      id=$scanId;cat=$category;msg=([string]$_.Exception.Message).Substring(0,[Math]::Min(3900,([string]$_.Exception.Message).Length))
     })
    }
   }
  }
  if($true) {
   $dbs=Invoke-DbTable $src 'SELECT name FROM sys.databases WHERE state=0 AND HAS_DBACCESS(name)=1 ORDER BY database_id;'
   foreach($db in $dbs.Rows) {
    $dbName=[string]$db['name']
    if(-not $systemDbs -and $dbName -in @('master','model','msdb','tempdb')) { continue }
    $dbc=$null
    try {
     $dbc=Open-Db $serverName $dbName $SourceCredential
     $databaseQueriesToRun=if($dbSecurity){ $dbQueries } else { [ordered]@{} }
     foreach($category in $databaseQueriesToRun.Keys) {
      try {
       $table=Invoke-DbTable $dbc $dbQueries[$category]
       $count=Save-Category $category $table $keyMap[$category] $scanId $repo
       $rows+=$count
       if(-not $categoryCounts.ContainsKey($category)) { $categoryCounts[$category]=0 }
       $categoryCounts[$category]+=$count
      } catch {
       $errors++
       $categoryErrors[$category]=$true
       Write-Warning "$serverName / $dbName / $category : $($_.Exception.Message)"
       if($Persist) {
        [void](Invoke-DbCommand -Connection $repo -Sql 'INSERT inventory.ScanFinding(ScanRunId,Category,Severity,Message) VALUES(@id,@cat,''ERROR'',@msg)' -SqlParameters @{
          id=$scanId;cat=$category;msg=("$dbName : $($_.Exception.Message)").Substring(0,[Math]::Min(3900,("$dbName : $($_.Exception.Message)").Length))
        })
       }
      }
     }
     foreach($category in $extendedDbQueries.Keys) {
      try {
       $table=Invoke-DbTable $dbc $extendedDbQueries[$category]
       $count=Save-Category $category $table $extendedKeys[$category] $scanId $repo
       $rows+=$count
       if(-not $categoryCounts.ContainsKey($category)) { $categoryCounts[$category]=0 }
       $categoryCounts[$category]+=$count
      } catch {
       $errors++
       $categoryErrors[$category]=$true
       Write-Warning "$serverName / $dbName / $category : $($_.Exception.Message)"
       if($Persist) {
        [void](Invoke-DbCommand -Connection $repo -Sql 'INSERT inventory.ScanFinding(ScanRunId,Category,Severity,Message) VALUES(@id,@cat,''ERROR'',@msg)' -SqlParameters @{
         id=$scanId;cat=$category;msg=("$dbName : $($_.Exception.Message)").Substring(0,[Math]::Min(3900,("$dbName : $($_.Exception.Message)").Length))
        })
       }
      }
     }
    } catch {
     $errors++
     foreach($category in $extendedDbQueries.Keys) { $categoryErrors[$category]=$true }
     if($dbSecurity) { foreach($category in $dbQueries.Keys) { $categoryErrors[$category]=$true } }
     Write-Warning "$serverName / $dbName : $($_.Exception.Message)"
     if($Persist) {
      [void](Invoke-DbCommand -Connection $repo -Sql 'INSERT inventory.ScanFinding(ScanRunId,Category,Severity,Message) VALUES(@id,@cat,''ERROR'',@msg)' -SqlParameters @{
       id=$scanId;cat='DATABASE_USER';msg=("$dbName : $($_.Exception.Message)").Substring(0,[Math]::Min(3900,("$dbName : $($_.Exception.Message)").Length))
      })
     }
    } finally { if($null -ne $dbc) { $dbc.Dispose() } }
   }
  }
  if($Persist) {
   $allCategories=@($queries.Keys)+@($extendedServerQueries.Keys)+@($extendedDbQueries.Keys)
   if($dbSecurity) { $allCategories+=@($dbQueries.Keys) }
   foreach($category in ($allCategories | Select-Object -Unique)) {
    $status=if($categoryErrors.ContainsKey($category)){'PARTIAL'}else{'COMPLETE'}
    $count=if($categoryCounts.ContainsKey($category)){[long]$categoryCounts[$category]}else{0L}
    [void](Invoke-DbCommand -Connection $repo -Sql @'
INSERT inventory.ScanCategory(ScanRunId,Category,CategoryStatus,RowCount)
VALUES(@id,@cat,@status,@rows);
'@ -SqlParameters @{id=$scanId;cat=$category;status=$status;rows=$count})
   }
   $state=if($errors -eq 0){'COMPLETE'}else{'PARTIAL'}
   [void](Invoke-DbCommand -Connection $repo -Sql @'
UPDATE inventory.ScanRun SET ScanStatus=@status,FinishedUtc=SYSUTCDATETIME()
WHERE ScanRunId=@id;
'@ -SqlParameters @{id=$scanId;status=$state})
   if($state -eq 'COMPLETE') {
    $changeReport=Invoke-DbTable $repo "EXEC inventory.usp_CompareCompletedScans @ScanRunId=$scanId;"
    foreach($r in $changeReport.Rows) {
     Write-Host "  Diff: $($r['Result']) changes=$($r['Changes']) previous=$($r['PreviousScanRunId'])"
    }
   }
  }
  Write-Host "Result: $serverName; rows=$rows; errors=$errors; scanId=$scanId"
 } catch {
  Write-Warning "Inventory failed for $serverName : $($_.Exception.Message)"
  Write-Warning "Location: $($_.InvocationInfo.PositionMessage)"
  Write-Warning "Script stack: $($_.ScriptStackTrace)"
  if($Persist -and $scanId -gt 0 -and $null -ne $repo) {
   try { [void](Invoke-DbCommand -Connection $repo -Sql "UPDATE inventory.ScanRun SET ScanStatus='FAILED',FinishedUtc=SYSUTCDATETIME(),ErrorMessage=@msg WHERE ScanRunId=@id;" -SqlParameters @{
    id=$scanId;msg=([string]$_.Exception.Message).Substring(0,[Math]::Min(3900,([string]$_.Exception.Message).Length))
   }) } catch { Write-Warning "Unable to mark scan $scanId FAILED" }
  }
  $global:LASTEXITCODE=1
 } finally {
  if($null -ne $src) { $src.Dispose() }
  if($null -ne $repo) { $repo.Dispose() }
 }
}
