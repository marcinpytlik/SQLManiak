#requires -Version 7.0
<#
.SYNOPSIS
 SQLManiak v4.2 read-only readiness check for Windows SQL Server / FCI.
.DESCRIPTION
 Uses integrated authentication by default. Optional -Credential for isolated LAB.
 Executes metadata and DMV queries without writing to the source or repository.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$ServerInstance,
 [System.Management.Automation.PSCredential]$Credential,
 [switch]$TrustServerCertificate,
 [string]$CsvPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module SqlServer -ErrorAction Stop
$common=@{
 ServerInstance=$ServerInstance
 Encrypt='Mandatory'
 TrustServerCertificate=[bool]$TrustServerCertificate
 ConnectionTimeout=10
 QueryTimeout=30
 ErrorAction='Stop'
}
if($null -ne $Credential) {
 $common['Username']=$Credential.UserName
 $common['Password']=$Credential.GetNetworkCredential().Password
}
function Invoke-Check {
 param([string]$Name,[string]$Database,[string]$Sql)
 $p=$common.Clone()
 $p['Database']=$Database
 $p['Query']=$Sql
 try {
  $result=Invoke-Sqlcmd @p
  [pscustomobject]@{Check=$Name;Database=$Database;Status='PASS';Rows=@($result).Count;Error=''}
 } catch {
  [pscustomobject]@{Check=$Name;Database=$Database;Status='FAIL';Rows=0;Error=$_.Exception.Message}
 }
}
$p=$common.Clone()
$p['Database']='master'
$p['Query']=@'
SELECT @@SERVERNAME AS ServerName,
 CONVERT(int,SERVERPROPERTY('ProductMajorVersion')) AS MajorVersion,
 CONVERT(int,SERVERPROPERTY('IsClustered')) AS IsClustered,
 CONVERT(int,SERVERPROPERTY('IsHadrEnabled')) AS IsHadrEnabled,
 CONVERT(nvarchar(128),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) AS PhysicalNode,
 CONVERT(nvarchar(128),SERVERPROPERTY('MachineName')) AS SqlNetworkName,
 SYSTEM_USER AS ExecutionLogin,
 HAS_PERMS_BY_NAME(NULL,NULL,'VIEW ANY DEFINITION') AS CanViewAnyDefinition,
 HAS_PERMS_BY_NAME(NULL,NULL,'VIEW SERVER STATE') AS CanViewServerState;
'@
$meta=Invoke-Sqlcmd @p
Write-Host "SQLManiak v4.2 readiness | $ServerInstance | $($meta.ServerName) | SQL major=$($meta.MajorVersion)"
Write-Host "Identity: $($meta.ExecutionLogin) | PhysicalNode=$($meta.PhysicalNode) | FCI=$($meta.IsClustered) | HADR=$($meta.IsHadrEnabled)"
$checks=[System.Collections.Generic.List[object]]::new()
$checks.Add((Invoke-Check 'Instance / catalog metadata' 'master' 'SELECT TOP(1) name FROM sys.databases;'))
$checks.Add((Invoke-Check 'Database files' 'master' 'SELECT TOP(1) database_id,file_id FROM sys.master_files;'))
$checks.Add((Invoke-Check 'Server configuration' 'master' 'SELECT TOP(1) name FROM sys.configurations;'))
$checks.Add((Invoke-Check 'Server principals' 'master' 'SELECT TOP(1) principal_id FROM sys.server_principals;'))
$checks.Add((Invoke-Check 'Volume DMV' 'master' 'SELECT TOP(1) volume_mount_point,available_bytes FROM sys.master_files f CROSS APPLY sys.dm_os_volume_stats(f.database_id,f.file_id);'))
$checks.Add((Invoke-Check 'Service DMV' 'master' 'SELECT TOP(1) servicename,status_desc FROM sys.dm_server_services;'))
$checks.Add((Invoke-Check 'Agent jobs' 'msdb' 'SELECT TOP(1) job_id,name FROM msdb.dbo.sysjobs;'))
$checks.Add((Invoke-Check 'Agent steps' 'msdb' 'SELECT TOP(1) job_id,step_id FROM msdb.dbo.sysjobsteps;'))
$checks.Add((Invoke-Check 'Agent schedules' 'msdb' 'SELECT TOP(1) schedule_id FROM msdb.dbo.sysschedules;'))
$checks.Add((Invoke-Check 'Trace flag state' 'master' 'DBCC TRACESTATUS(-1) WITH NO_INFOMSGS;'))
if([int]$meta.IsClustered -eq 1) {
 $checks.Add((Invoke-Check 'FCI nodes and owner' 'master' 'SELECT NodeName,is_current_owner FROM sys.dm_os_cluster_nodes;'))
}
if([int]$meta.IsHadrEnabled -eq 1) {
 $checks.Add((Invoke-Check 'AG replicas' 'master' 'SELECT TOP(1) replica_server_name FROM sys.availability_replicas;'))
 $checks.Add((Invoke-Check 'AG local replica states' 'master' 'SELECT TOP(1) role_desc FROM sys.dm_hadr_availability_replica_states;'))
}
$p=$common.Clone()
$p['Database']='master'
$p['Query']="SELECT name FROM sys.databases WHERE state=0 AND HAS_DBACCESS(name)=1;"
$dbs=Invoke-Sqlcmd @p
foreach($db in $dbs) {
 $dbName=[string]$db.name
 $checks.Add((Invoke-Check 'DB objects and indexes' $dbName 'SELECT TOP(1) o.object_id,i.index_id FROM sys.objects o JOIN sys.indexes i ON i.object_id=o.object_id;'))
 $checks.Add((Invoke-Check 'DB security catalog' $dbName 'SELECT TOP(1) grantee_principal_id FROM sys.database_permissions;'))
}
$checks | Format-Table Check,Database,Status,Rows,Error -AutoSize -Wrap
if($CsvPath) {
 $checks | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding utf8
 Write-Host "Saved CSV: $CsvPath"
}
$fails=@($checks | Where-Object Status -eq 'FAIL')
Write-Host "Readiness: checks=$($checks.Count); failures=$($fails.Count)"
if($fails.Count -gt 0) { throw "Readiness failed: $($fails.Count) checks; no changes made." }
