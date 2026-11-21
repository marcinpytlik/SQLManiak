#requires -Version 7.0
<#
.SYNOPSIS
 Read-only observation of SQL32 FCI; writes only into LOCAL Docker LAB repository.
.DESCRIPTION
 Source: SQL32,1530 using Windows Integrated Authentication. Only SELECT queries.
 Destination: 127.0.0.1,15433 / DBACentralRepositoryv4 using LAB SA credential from docker/.env.
 Does not initiate failover, restart, or change anything on FCI/WSFC.
 Run only after the LAB repository has been installed through 06_FCI_Owner_Observation.sql.
#>
[CmdletBinding()]
param(
 [switch]$PreviewOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$expectedServer='SQL32\SQLINS32'
$sourceEndpoint='SQL32,1530'
$repositoryEndpoint='127.0.0.1,15433'
$repositoryDatabase='DBACentralRepositoryv4'
Import-Module SqlServer -ErrorAction Stop

# Read-only checks against the actual FCI. Never change source state.
$sourceParams=@{
 ServerInstance=$sourceEndpoint
 Database='master'
 Encrypt='Mandatory'
 TrustServerCertificate=$false
 ConnectionTimeout=10
 QueryTimeout=30
 ErrorAction='Stop'
}
$identity=Invoke-Sqlcmd @sourceParams -Query @'
SELECT CAST(@@SERVERNAME AS nvarchar(256)) AS ServerName,
 CAST(SERVERPROPERTY('IsClustered') AS int) AS IsClustered,
 CAST(SERVERPROPERTY('MachineName') AS nvarchar(128)) AS SqlVirtualName,
 CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS nvarchar(128)) AS PhysicalNode;
'@
if($null -eq $identity -or [string]$identity.ServerName -ne $expectedServer -or [int]$identity.IsClustered -ne 1) {
 throw "SAFETY STOP: expected FCI $expectedServer. Got $($identity.ServerName), IsClustered=$($identity.IsClustered)."
}
$nodes=@(Invoke-Sqlcmd @sourceParams -Query @'
SELECT CAST(NodeName AS nvarchar(128)) AS NodeName,
 CAST(status_description AS nvarchar(60)) AS NodeStatus,
 CAST(is_current_owner AS bit) AS IsCurrentOwner
FROM sys.dm_os_cluster_nodes
ORDER BY NodeName;
'@)
if($nodes.Count -lt 2) { throw "SAFETY STOP: expected at least 2 FCI nodes, got $($nodes.Count)." }
$owners=@($nodes | Where-Object { [int]$_.IsCurrentOwner -eq 1 })
if($owners.Count -ne 1) { throw "SAFETY STOP: expected 1 current owner, got $($owners.Count)." }
Write-Host "FCI source: $($identity.ServerName) | VNN=$($identity.SqlVirtualName) | physical=$($identity.PhysicalNode)"
$nodes | Select-Object NodeName,NodeStatus,IsCurrentOwner | Format-Table -AutoSize
Write-Host "Current owner: $($owners[0].NodeName). Manual failover policy: OBSERVE ONLY."
if($PreviewOnly) { Write-Host 'PREVIEW ONLY: no repository connection or write.'; return }

# Destination is checked independently and restricted to the LOCAL Docker LAB.
$envPath=Join-Path $root 'docker/.env'
if(-not (Test-Path -LiteralPath $envPath)) { throw 'Missing docker/.env; create Docker LAB first.' }
$passwordLine=Get-Content -LiteralPath $envPath | Where-Object { $_ -match '^REPO_SA_PASSWORD=' } | Select-Object -First 1
if(-not $passwordLine) { throw 'Missing REPO_SA_PASSWORD in docker/.env.' }
$secret=[string]($passwordLine -replace '^REPO_SA_PASSWORD=','')
if([string]::IsNullOrWhiteSpace($secret)) { throw 'Empty repository password.' }
if(-not ('System.Data.SqlClient.SqlConnection' -as [type])) { Add-Type -AssemblyName System.Data.SqlClient -ErrorAction Stop }
$builder=[System.Data.SqlClient.SqlConnectionStringBuilder]::new()
$builder['Data Source']=$repositoryEndpoint
$builder['Initial Catalog']=$repositoryDatabase
$builder['User ID']='sa'
$builder['Password']=$secret
$builder['Encrypt']=$true
$builder['TrustServerCertificate']=$true
$builder['Connect Timeout']=5
$cn=[System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
try {
 $cn.Open()
 $cmd=$cn.CreateCommand()
 $cmd.CommandTimeout=30
 $cmd.CommandText=@'
SELECT DB_NAME() AS DatabaseName, @@SERVERNAME AS ServerName,
 OBJECT_ID(N'inventory.usp_RecordFciObservation',N'P') AS FciProcId;
'@
 $check=$cmd.ExecuteReader()
 try {
  if(-not $check.Read()) { throw 'Repository check returned no rows.' }
  $databaseName=[string]$check['DatabaseName']
  $serverName=[string]$check['ServerName']
  $procExists= -not ($check['FciProcId'] -is [DBNull])
 } finally { $check.Close();$cmd.Dispose() }
 if($databaseName -ne $repositoryDatabase -or $serverName -ne 'sqlmaniak-v4-repo' -or -not $procExists) {
  throw "SAFETY STOP: repository mismatch: $serverName / $databaseName / FCI proc=$procExists"
 }
 $records=[System.Collections.Generic.List[object]]::new()
 foreach($node in $nodes) {
  $records.Add([pscustomobject]@{
   NodeName=[string]$node.NodeName
   NodeStatus=if($null -eq $node.NodeStatus){$null}else{[string]$node.NodeStatus}
   IsCurrentOwner=([int]$node.IsCurrentOwner -eq 1)
  })
 }
 $json=ConvertTo-Json -InputObject @($records.ToArray()) -Depth 4 -Compress
 $cmd=$cn.CreateCommand()
 $cmd.CommandTimeout=30
 $cmd.CommandText=@'
SET XACT_ABORT ON;
BEGIN TRAN;
DECLARE @InstanceId bigint;
SELECT @InstanceId=InstanceId FROM inventory.Instance WITH(UPDLOCK,HOLDLOCK)
 WHERE ServerInstance=@instance;
IF @InstanceId IS NULL
BEGIN
 INSERT inventory.Instance(ServerInstance,EnvironmentCode,Architecture)
 VALUES(@instance,'PROD','FCI');
 SET @InstanceId=SCOPE_IDENTITY();
END;
DECLARE @ExistingArchitecture varchar(20);
SELECT @ExistingArchitecture=Architecture FROM inventory.Instance WHERE InstanceId=@InstanceId;
IF @ExistingArchitecture<>'FCI' THROW 54210,'Existing instance is not categorized as FCI.',1;
INSERT inventory.ScanRun(InstanceId,ScanType,CollectorVersion)
VALUES(@InstanceId,'FULL','4.2-fci-owner-only');
SELECT CONVERT(bigint,SCOPE_IDENTITY()) AS ScanRunId;
COMMIT;
'@
 [void]$cmd.Parameters.AddWithValue('@instance',$expectedServer)
 try { $scanId=[long]$cmd.ExecuteScalar() } finally { $cmd.Dispose() }
 try {
  $cmd=$cn.CreateCommand()
  $cmd.CommandTimeout=30
  $cmd.CommandText='EXEC inventory.usp_RecordFciObservation @ScanRunId=@id,@NodesJson=@json;'
  [void]$cmd.Parameters.AddWithValue('@id',$scanId)
  [void]$cmd.Parameters.AddWithValue('@json',$json)
  try { $saved=$cmd.ExecuteReader(); try { while($saved.Read()) {
   Write-Host "FCI observation saved: ScanRunId=$($saved['ScanRunId']) Owner=$($saved['CurrentOwner']) Changed=$($saved['OwnerChanged'])"
  }} finally {$saved.Close()} } finally {$cmd.Dispose()}
  $cmd=$cn.CreateCommand()
  $cmd.CommandText="UPDATE inventory.ScanRun SET ScanStatus='COMPLETE',FinishedUtc=SYSUTCDATETIME() WHERE ScanRunId=@id;"
  [void]$cmd.Parameters.AddWithValue('@id',$scanId)
  try { [void]$cmd.ExecuteNonQuery() } finally {$cmd.Dispose()}
 } catch {
  $cmd=$cn.CreateCommand()
  $cmd.CommandText="UPDATE inventory.ScanRun SET ScanStatus='FAILED',FinishedUtc=SYSUTCDATETIME(),ErrorMessage=@message WHERE ScanRunId=@id;"
  [void]$cmd.Parameters.AddWithValue('@id',$scanId)
  [void]$cmd.Parameters.AddWithValue('@message',([string]$_.Exception.Message).Substring(0,[Math]::Min(3900,([string]$_.Exception.Message).Length)))
  try { [void]$cmd.ExecuteNonQuery() } finally {$cmd.Dispose()}
  throw
 }
} finally { $cn.Dispose() }
Write-Host 'Source remained read-only; repository observation completed.'
