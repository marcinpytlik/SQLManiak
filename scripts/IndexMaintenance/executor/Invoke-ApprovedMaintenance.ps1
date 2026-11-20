#requires -Version 7.5
<#
 Default: preview approved queue item. Execute requires both -Execute and -ConfirmExecution.
 No job backup stoppage; no offline REBUILD fallback; one item per invocation.
 Note: review log space, TempDB, backup windows, edition and client timeouts.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$RepositoryServer,
 [Parameter(Mandatory)][long]$QueueId,
 [switch]$Execute,
 [switch]$ConfirmExecution,
 [switch]$TrustServerCertificate,
 [int]$CommandTimeoutSeconds=7200
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName 'Microsoft.Data.SqlClient'
function Open-Sql([string]$server,[string]$database){
 $b=[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new()
 $b.DataSource=$server; $b.InitialCatalog=$database
 $b.IntegratedSecurity=$true; $b.Encrypt=[Microsoft.Data.SqlClient.SqlConnectionEncryptOption]::Mandatory
 $b.TrustServerCertificate=[bool]$TrustServerCertificate;$b.ConnectTimeout=15
 $c=[Microsoft.Data.SqlClient.SqlConnection]::new($b.ConnectionString);$c.Open();return $c
}
function Quote-Sql([string]$name){return '['+$name.Replace(']',']]')+']'}
if($Execute -and -not $ConfirmExecution){throw 'Execution requires both -Execute and -ConfirmExecution'}
$repo=Open-Sql $RepositoryServer 'SQLManiakIndexMaintenance'
$token=$null;$claimed=$false;$finished=$false;$target=$null
try{
 $preview=$repo.CreateCommand()
 $preview.CommandText='SELECT * FROM im.PendingMaintenance WHERE QueueId=@id AND Status=''Approved'''
 [void]$preview.Parameters.Add('@id',[System.Data.SqlDbType]::BigInt)
 $preview.Parameters['@id'].Value=$QueueId
 $dt=[System.Data.DataTable]::new();$r=$preview.ExecuteReader();try{$dt.Load($r)}finally{$r.Dispose();$preview.Dispose()}
 if($dt.Rows.Count -ne 1){throw 'Queue item is not approved or its endpoint is unavailable'}
 $row=$dt.Rows[0]
 if([string]::IsNullOrWhiteSpace([string]$row.ServerAddress)){throw 'No enabled endpoint'}
 $server=[string]$row.ServerAddress
 if(-not $row.IsNull('Port')){$server+=','+[string]$row.Port}
 $db=[string]$row.DatabaseName
 $op=[string]$row.Operation
 $command='ALTER INDEX '+(Quote-Sql ([string]$row.IndexName))+' ON '+(Quote-Sql ([string]$row.SchemaName))+'.'+(Quote-Sql ([string]$row.TableName))
 if($op -eq 'REORGANIZE'){
  $command+=' REORGANIZE PARTITION = '+[int]$row.PartitionNumber+';'
 }elseif($op -eq 'REBUILD'){
  $command+=' REBUILD PARTITION = '+[int]$row.PartitionNumber+
   ' WITH (ONLINE = ON (WAIT_AT_LOW_PRIORITY (MAX_DURATION = 5 MINUTES, ABORT_AFTER_WAIT = SELF)), MAXDOP = 2);'
 }else{throw 'Unsupported operation'}
 Write-Output "Server=$server Database=$db QueueId=$QueueId"
 Write-Output "Preview: $command"
 if(-not $Execute){Write-Output 'DRY RUN: No SQL statement was executed';return}
 # Claim exclusively and obtain a fencing token.
 $claim=$repo.CreateCommand();$claim.CommandText='im.ClaimMaintenance'
 $claim.CommandType=[System.Data.CommandType]::StoredProcedure
 [void]$claim.Parameters.Add('@QueueId',[System.Data.SqlDbType]::BigInt)
 $claim.Parameters['@QueueId'].Value=$QueueId
 $p=$claim.Parameters.Add('@ExecutionToken',[System.Data.SqlDbType]::UniqueIdentifier)
 $p.Direction=[System.Data.ParameterDirection]::Output
 $claimResult=[System.Data.DataTable]::new()
 # ExecuteReader is needed because procedure returns metadata. Output token populated when reader closes.
 $reader=$claim.ExecuteReader()
 try{$claimResult.Load($reader)}finally{$reader.Dispose()}
 $token=[guid]$p.Value;$claimed=$true;$claim.Dispose()
 if($claimResult.Rows.Count -ne 1){throw 'Claim returned unexpected number of rows'}
 $claimedRow=$claimResult.Rows[0]
 if([long]$claimedRow.QueueId -ne $QueueId -or [string]$claimedRow.DatabaseName -ne $db -or
    [string]$claimedRow.ServerAddress -ne [string]$row.ServerAddress -or
    [int]$claimedRow.ObjectId -ne [int]$row.ObjectId -or
    [int]$claimedRow.IndexId -ne [int]$row.IndexId) {throw 'Claimed target changed since preview'}
 $target=Open-Sql $server $db
 # Guard against renamed/replaced indexes, wrong instance and a stale plan.
 $verify=$target.CreateCommand()
 $verify.CommandText=@'
SELECT COUNT_BIG(*) FROM sys.indexes i
JOIN sys.tables t ON t.object_id=i.object_id
JOIN sys.schemas s ON s.schema_id=t.schema_id
JOIN sys.partitions p ON p.object_id=i.object_id AND p.index_id=i.index_id
WHERE i.object_id=@obj AND i.index_id=@idx AND p.partition_number=@part
 AND s.name=@schema AND t.name=@tbl AND i.name=@ind
 AND i.is_disabled=0 AND i.is_hypothetical=0 AND i.type IN (1,2);
'@
 foreach($spec in @(
   @('obj',[System.Data.SqlDbType]::Int,[int]$row.ObjectId),
   @('idx',[System.Data.SqlDbType]::Int,[int]$row.IndexId),
   @('part',[System.Data.SqlDbType]::Int,[int]$row.PartitionNumber),
   @('schema',[System.Data.SqlDbType]::NVarChar,[string]$row.SchemaName),
   @('tbl',[System.Data.SqlDbType]::NVarChar,[string]$row.TableName),
   @('ind',[System.Data.SqlDbType]::NVarChar,[string]$row.IndexName))){
   $p=$verify.Parameters.Add('@'+$spec[0],$spec[1]);$p.Value=$spec[2]
 }
 $matches=[long]$verify.ExecuteScalar();$verify.Dispose()
 if($matches -ne 1){throw 'Live metadata does not match assessed object/index/partition'}
 # Rebuild capability checks. Do not silently fall back to OFFLINE.
 if($op -eq 'REBUILD'){
  $edition=[string]$target.CreateCommand().Connection.ServerVersion
  Write-Output "Target SQL version: $edition; ONLINE=ON must be supported by target edition/index."
 }
 $cmd=$target.CreateCommand();$cmd.CommandText=$command
 $cmd.CommandTimeout=$CommandTimeoutSeconds
 [void]$cmd.ExecuteNonQuery();$cmd.Dispose()
 Write-Output 'Maintenance executed successfully'
 $status='Completed';$message='Completed using explicit approval and online-only rebuild policy'
}catch{
 if($claimed){$status='Failed';$message=$_.Exception.Message}
 throw
}finally{
 if($target){$target.Dispose()}
 if($claimed -and -not $finished){
  try{
   $finish=$repo.CreateCommand()
   $finish.CommandType=[System.Data.CommandType]::StoredProcedure
   $finish.CommandText='im.FinishMaintenance'
   foreach($spec in @(
    @('QueueId',[System.Data.SqlDbType]::BigInt,$QueueId),
    @('ExecutionToken',[System.Data.SqlDbType]::UniqueIdentifier,$token),
    @('Status',[System.Data.SqlDbType]::VarChar,$status),
    @('Message',[System.Data.SqlDbType]::NVarChar,([string]$message).Substring(0,[Math]::Min(4000,([string]$message).Length))))){
     $p=$finish.Parameters.Add('@'+$spec[0],$spec[1]);$p.Value=$spec[2]
   }
   [void]$finish.ExecuteNonQuery();$finish.Dispose()
  }catch{Write-Warning "Could not write terminal status for QueueId=$QueueId : $_"}
 }
 $repo.Dispose()
}
