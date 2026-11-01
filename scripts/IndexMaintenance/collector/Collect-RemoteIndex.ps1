#requires -Version 7.5
<#
.SYNOPSIS
 Read-only remote index collector: exports JSON to stdout / file; no REBUILD.
 Requires Microsoft.Data.SqlClient (load assembly or SqlServer module dependency).
 Example: ./Collect-RemoteIndex.ps1 -Server 'SQLVNN\\INST1' -Database 'AppDb' -OutputPath '.\\audit.json'
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$Server,
 [Parameter(Mandatory)][string]$Database,
 [Parameter(Mandatory)][string]$OutputPath,
 [int]$MinPagesForReview=1000,
 [int]$MinPagesForSample=10000,
 [int]$MaxSampledPartitions=20,
 [switch]$TrustServerCertificate
)
$ErrorActionPreference='Stop'
if($MinPagesForReview -lt 1 -or $MinPagesForSample -lt $MinPagesForReview -or $MaxSampledPartitions -lt 0){throw 'Invalid limits'}
Add-Type -AssemblyName 'Microsoft.Data.SqlClient'
$builder=[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new()
$builder.DataSource=$Server
$builder.InitialCatalog=$Database
$builder.IntegratedSecurity=$true
$builder.Encrypt=[Microsoft.Data.SqlClient.SqlConnectionEncryptOption]::Mandatory
$builder.TrustServerCertificate=[bool]$TrustServerCertificate
$builder.ConnectTimeout=15
$conn=[Microsoft.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
try {
 $conn.Open()
 $cmd=$conn.CreateCommand()
 $cmd.CommandTimeout=0
 $cmd.CommandText=@'
SELECT i.object_id ObjectId,i.index_id IndexId,p.partition_number PartitionNumber,
s.name SchemaName,o.name TableName,i.name IndexName,i.type IndexType,
p.page_count PageCount,p.avg_fragmentation_in_percent FragmentationPercent,
p.avg_page_space_used_in_percent PageDensityPercent,
CAST('LIMITED' AS varchar(10)) MeasurementMode
FROM sys.indexes i
JOIN sys.objects o ON o.object_id=i.object_id AND o.type='U'
JOIN sys.schemas s ON s.schema_id=o.schema_id
CROSS APPLY sys.dm_db_index_physical_stats(DB_ID(),i.object_id,i.index_id,NULL,'LIMITED') p
WHERE i.type IN (1,2) AND i.is_disabled=0 AND i.is_hypothetical=0
 AND p.alloc_unit_type_desc='IN_ROW_DATA' AND p.index_level=0
 AND p.page_count >= @MinPages;
'@
 [void]$cmd.Parameters.Add('@MinPages',[System.Data.SqlDbType]::Int)
 $cmd.Parameters['@MinPages'].Value=$MinPagesForReview
 $table=[System.Data.DataTable]::new()
 $reader=$cmd.ExecuteReader()
 try {$table.Load($reader)} finally {$reader.Dispose()}
 $records=[System.Collections.Generic.List[object]]::new()
 foreach($r in $table.Rows){
  $records.Add([pscustomobject]@{
   ObjectId=[int]$r.ObjectId;IndexId=[int]$r.IndexId;PartitionNumber=[int]$r.PartitionNumber;
   SchemaName=[string]$r.SchemaName;TableName=[string]$r.TableName;IndexName=[string]$r.IndexName;
   IndexType=[int]$r.IndexType;PageCount=[long]$r.PageCount;
   FragmentationPercent=if($r.IsNull('FragmentationPercent')){$null}else{[double]$r.FragmentationPercent};
   PageDensityPercent=if($r.IsNull('PageDensityPercent')){$null}else{[double]$r.PageDensityPercent};
   MeasurementMode='LIMITED'
  })
 }
 # SAMPLED: bounded to top partitions, separately queried by object/index/partition.
 foreach($target in @($records | Where-Object PageCount -GE $MinPagesForSample | Sort-Object PageCount -Descending | Select-Object -First $MaxSampledPartitions)){
  $s=$conn.CreateCommand()
  $s.CommandTimeout=0
  $s.CommandText="SELECT TOP (1) avg_fragmentation_in_percent,avg_page_space_used_in_percent FROM sys.dm_db_index_physical_stats(DB_ID(),@o,@i,@p,'SAMPLED') WHERE index_level=0 AND alloc_unit_type_desc='IN_ROW_DATA'"
  foreach($pair in @(@('o',$target.ObjectId),@('i',$target.IndexId),@('p',$target.PartitionNumber))){[void]$s.Parameters.Add("@$($pair[0])",[System.Data.SqlDbType]::Int);$s.Parameters["@$($pair[0])"].Value=$pair[1]}
  $rd=$s.ExecuteReader()
  try {if($rd.Read()) {
   $target.FragmentationPercent=if($rd.IsDBNull(0)){$null}else{$rd.GetDouble(0)}
   $target.PageDensityPercent=if($rd.IsDBNull(1)){$null}else{$rd.GetDouble(1)}
   $target.MeasurementMode='SAMPLED'
  }}finally{$rd.Dispose();$s.Dispose()}
 }
 $payload=[pscustomobject]@{Server=$Server;Database=$Database;CollectedAtUtc=[DateTime]::UtcNow.ToString('o');Partitions=@($records)}
 $payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
 Write-Output "Collected $($records.Count) index partitions to $OutputPath"
}finally{$conn.Dispose()}
