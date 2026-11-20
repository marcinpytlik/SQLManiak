#requires -Version 7.5
<#
 Imports historical index measurements from CSV, one-way into im.IndexHistory.
 Required headers: DateTime,Server,Database,Table,IndexName,AvgFragmentationPot,TotalPageCount,PartitionCount
 Test small extracts first. Re-importing same file causes duplicates; use -WhatIf first.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
 [Parameter(Mandatory)][string]$RepositoryServer,
 [Parameter(Mandatory)][string]$Path,
 [Parameter(Mandatory)][string]$SourceName,
 [char]$Delimiter=',',
 [int]$BatchSize=5000,
 [switch]$TrustServerCertificate
)
$ErrorActionPreference='Stop'
if($BatchSize -lt 1 -or $BatchSize -gt 50000){throw 'BatchSize must be 1-50000'}
if(-not(Test-Path -LiteralPath $Path)){throw 'CSV not found'}
Add-Type -AssemblyName 'Microsoft.Data.SqlClient'
$columns=[ordered]@{
 SourceName=[string];MeasuredAt=[datetime];ServerName=[string];DatabaseName=[string]
 TableName=[string];IndexName=[string];AvgFragmentationPct=[double]
 TotalPageCount=[long];PartitionCount=[int]
}
$dt=[System.Data.DataTable]::new()
foreach($name in $columns.Keys){[void]$dt.Columns.Add($name,$columns[$name])}
$b=[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new()
$b.DataSource=$RepositoryServer;$b.InitialCatalog='SQLManiakIndexMaintenance'
$b.IntegratedSecurity=$true;$b.Encrypt=[Microsoft.Data.SqlClient.SqlConnectionEncryptOption]::Mandatory
$b.TrustServerCertificate=[bool]$TrustServerCertificate
$conn=[Microsoft.Data.SqlClient.SqlConnection]::new($b.ConnectionString)
$written=0;$count=0
function Flush-Batch{
 if($dt.Rows.Count -eq 0){return}
 if($PSCmdlet.ShouldProcess("im.IndexHistory on $RepositoryServer","Insert $($dt.Rows.Count) rows")){
  $bulk=[Microsoft.Data.SqlClient.SqlBulkCopy]::new($conn)
  try{
   $bulk.DestinationTableName='im.IndexHistory';$bulk.BulkCopyTimeout=300
   foreach($column in $dt.Columns){[void]$bulk.ColumnMappings.Add($column.ColumnName,$column.ColumnName)}
   $bulk.WriteToServer($dt)
   $script:written+=$dt.Rows.Count
  }finally{$bulk.Dispose()}
 }
 $dt.Clear()
}
try{
 if(-not $WhatIfPreference){$conn.Open()}
 foreach($r in (Import-Csv -LiteralPath $Path -Delimiter $Delimiter)){
  $count++
  foreach($col in @('DateTime','Server','Database','Table','IndexName','TotalPageCount')){
   if([string]::IsNullOrWhiteSpace([string]$r.$col)){throw "Missing $col at row $count"}
  }
  $line=$dt.NewRow()
  $line['SourceName']=$SourceName
  $line['MeasuredAt']=[datetime]::Parse([string]$r.DateTime,[cultureinfo]::InvariantCulture)
  $line['ServerName']=[string]$r.Server
  $line['DatabaseName']=[string]$r.Database
  $line['TableName']=[string]$r.Table
  $line['IndexName']=[string]$r.IndexName
  $frag=[string]$r.AvgFragmentationPot
  $line['AvgFragmentationPct']=if([string]::IsNullOrWhiteSpace($frag)){[DBNull]::Value}else{[double]::Parse($frag,[cultureinfo]::InvariantCulture)}
  $line['TotalPageCount']=[long]::Parse([string]$r.TotalPageCount,[cultureinfo]::InvariantCulture)
  $pc=[string]$r.PartitionCount
  $line['PartitionCount']=if([string]::IsNullOrWhiteSpace($pc)){[DBNull]::Value}else{[int]::Parse($pc,[cultureinfo]::InvariantCulture)}
  $dt.Rows.Add($line)
  if($dt.Rows.Count -ge $BatchSize){Flush-Batch}
 }
 Flush-Batch
 Write-Output "Read=$count Inserted=$written; source=$SourceName"
}finally{$conn.Dispose()}
