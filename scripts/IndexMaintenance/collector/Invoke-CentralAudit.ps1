#requires -Version 7.5
<#
 Executes audits for enabled registered instances and databases.
 Microsoft.Data.SqlClient assembly required (SqlServer module or installed package).
 SECURITY: Windows authentication, TLS encryption and certificate verification by default.
 This is an early pilot: one sequential audit at a time, run on Windows.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$RepositoryServer,
 [int]$LeaseMinutes=240,
 [string]$OutputDirectory=(Join-Path $PSScriptRoot 'output'),
 [switch]$TrustServerCertificate)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName 'Microsoft.Data.SqlClient'
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
function New-Connection([string]$server,[string]$database){
 $b=[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new()
 $b.DataSource=$server;$b.InitialCatalog=$database;$b.IntegratedSecurity=$true
 $b.Encrypt=[Microsoft.Data.SqlClient.SqlConnectionEncryptOption]::Mandatory
 $b.TrustServerCertificate=[bool]$TrustServerCertificate
 $b.ConnectTimeout=15
 $c=[Microsoft.Data.SqlClient.SqlConnection]::new($b.ConnectionString)
 $c.Open()
 return $c
}
function Invoke-SqlNonQuery($connection,[string]$sql,[hashtable]$parameters){
 $cmd=$connection.CreateCommand()
 $cmd.CommandText=$sql
 $cmd.CommandTimeout=120
 foreach($key in $parameters.Keys){
  $value=$parameters[$key]
  $p=$cmd.Parameters.Add("@$key",[System.Data.SqlDbType]::NVarChar,4000)
  if($value -is [int] -or $value -is [long]){$p.SqlDbType=[System.Data.SqlDbType]::BigInt}
  elseif($value -is [guid]){$p.SqlDbType=[System.Data.SqlDbType]::UniqueIdentifier}
  $p.Value=$value
 }
 try {[void]$cmd.ExecuteNonQuery()}finally{$cmd.Dispose()}
}
$repo=New-Connection $RepositoryServer 'SQLManiakIndexMaintenance'
try {
 $cmd=$repo.CreateCommand()
 $cmd.CommandText=@'
SELECT i.InstanceId,i.InstanceName,e.ServerAddress,e.Port,d.DatabaseName,
 COALESCE(p.MinPagesForReview,1000) AS MinPagesForReview,
 COALESCE(p.MinPagesForSample,10000) AS MinPagesForSample,
 COALESCE(p.MaxSampledPartitions,20) AS MaxSampledPartitions
FROM im.ManagedInstance i
JOIN im.ConnectionEndpoint e ON e.InstanceId=i.InstanceId AND e.IsEnabled=1 AND e.IsPrimary=1
JOIN im.ManagedDatabase d ON d.InstanceId=i.InstanceId AND d.IsEnabled=1
LEFT JOIN im.AuditPolicy p ON p.PolicyId=d.PolicyId
WHERE i.IsEnabled=1 AND (p.PolicyId IS NULL OR p.IsEnabled=1)
ORDER BY i.InstanceId,d.DatabaseName;
'@
 $table=[System.Data.DataTable]::new();$rd=$cmd.ExecuteReader()
 try{$table.Load($rd)}finally{$rd.Dispose();$cmd.Dispose()}
 foreach($item in $table.Rows){
  $runId=$null;$token=$null
  $server=[string]$item.ServerAddress
  if(-not $item.IsNull('Port')){$server="$server,$($item.Port)"}
  $database=[string]$item.DatabaseName
  try {
   $begin=$repo.CreateCommand()
   $begin.CommandText='im.BeginRemoteAudit'
   $begin.CommandType=[System.Data.CommandType]::StoredProcedure
   [void]$begin.Parameters.Add('@InstanceId',[System.Data.SqlDbType]::BigInt)
   $begin.Parameters['@InstanceId'].Value=[long]$item.InstanceId
   [void]$begin.Parameters.Add('@DatabaseName',[System.Data.SqlDbType]::NVarChar,128)
   $begin.Parameters['@DatabaseName'].Value=$database
   [void]$begin.Parameters.Add('@LeaseMinutes',[System.Data.SqlDbType]::Int)
   $begin.Parameters['@LeaseMinutes'].Value=$LeaseMinutes
   $p=$begin.Parameters.Add('@RunId',[System.Data.SqlDbType]::BigInt)
   $p.Direction=[System.Data.ParameterDirection]::Output
   $p=$begin.Parameters.Add('@Token',[System.Data.SqlDbType]::UniqueIdentifier)
   $p.Direction=[System.Data.ParameterDirection]::Output
   [void]$begin.ExecuteNonQuery()
   $runId=[long]$begin.Parameters['@RunId'].Value
   $token=[guid]$begin.Parameters['@Token'].Value
   $begin.Dispose()
   $outfile=Join-Path $OutputDirectory "audit-$runId.json"
   & (Join-Path $PSScriptRoot 'Collect-RemoteIndex.ps1') -Server $server -Database $database -OutputPath $outfile -MinPagesForReview ([int]$item.MinPagesForReview) -MinPagesForSample ([int]$item.MinPagesForSample) -MaxSampledPartitions ([int]$item.MaxSampledPartitions) -TrustServerCertificate:$TrustServerCertificate
   if($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE){throw "Collector error $LASTEXITCODE"}
   $doc=Get-Content -LiteralPath $outfile -Raw | ConvertFrom-Json
   $stage=[System.Data.DataTable]::new()
   foreach($name in @('AuditRunId','ObjectId','IndexId','PartitionNumber','SchemaName','TableName','IndexName','IndexType','PageCount','FragmentationPercent','PageDensityPercent','MeasurementMode')){
    $type=if($name -in @('AuditRunId','PageCount')){[long]}
     elseif($name -in @('ObjectId','IndexId','PartitionNumber','IndexType')){[int]}
     elseif($name -in @('FragmentationPercent','PageDensityPercent')){[double]}
     else{[string]}
    [void]$stage.Columns.Add($name,$type)
   }
   foreach($r in $doc.Partitions){
    $row=$stage.NewRow()
    foreach($column in $stage.Columns){
     $v=if($column.ColumnName -eq 'AuditRunId'){$runId}else{$r.($column.ColumnName)}
     $row[$column.ColumnName]=if($null -eq $v){[DBNull]::Value}else{$v}
    }
    $stage.Rows.Add($row)
   }
   $bulk=[Microsoft.Data.SqlClient.SqlBulkCopy]::new($repo)
   try{
    $bulk.DestinationTableName='im.RemoteIndexStage'
    $bulk.BulkCopyTimeout=1200
    foreach($column in $stage.Columns){[void]$bulk.ColumnMappings.Add($column.ColumnName,$column.ColumnName)}
    $bulk.WriteToServer($stage)
   }finally{$bulk.Dispose()}
   Invoke-SqlNonQuery $repo 'EXEC im.ClassifyRemoteAudit @RunId=@RunId' @{RunId=$runId}
   Invoke-SqlNonQuery $repo "EXEC im.CompleteRemoteAudit @RunId=@RunId,@Token=@Token,@Status=N'Completed'" @{RunId=$runId;Token=$token}
   Write-Output "Completed AuditRunId=$runId ($server / $database): $($stage.Rows.Count) partitions"
  }catch{
   Write-Warning "Audit failed for $server/$database : $($_.Exception.Message)"
   if($null -ne $runId -and $null -ne $token){
    try {
     $msg=$_.Exception.Message
     $cmd=$repo.CreateCommand()
     $cmd.CommandText='im.CompleteRemoteAudit'
     $cmd.CommandType=[System.Data.CommandType]::StoredProcedure
     foreach($spec in @(@('RunId',[System.Data.SqlDbType]::BigInt,$runId),@('Token',[System.Data.SqlDbType]::UniqueIdentifier,$token),@('Status',[System.Data.SqlDbType]::VarChar,'Failed'),@('ErrorMessage',[System.Data.SqlDbType]::NVarChar,$msg.Substring(0,[Math]::Min(4000,$msg.Length))))){
      $p=$cmd.Parameters.Add('@'+$spec[0],$spec[1]);$p.Value=$spec[2]
     }
     [void]$cmd.ExecuteNonQuery();$cmd.Dispose()
    }catch{Write-Warning "Could not close audit run $runId: $_"}
   }
  }
 }
}finally{$repo.Dispose()}
