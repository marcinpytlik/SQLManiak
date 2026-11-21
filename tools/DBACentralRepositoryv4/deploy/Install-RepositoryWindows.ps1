#requires -Version 7.0
<#
.SYNOPSIS
  Controlled installation of SQLManiak DBACentralRepositoryv4 onto Windows SQL Server.
.DESCRIPTION
  Default: preflight only. -Install creates the dedicated DB and schema.
  Integrated Windows authentication, no Docker, no source FCI modifications.
  Uses explicit -ServerInstance and verifies DB name before running scripts.
.EXAMPLE
  ./deploy/Install-RepositoryWindows.ps1 -ServerInstance 'REPO-SQL\INSTANCE'
.EXAMPLE
  ./deploy/Install-RepositoryWindows.ps1 -ServerInstance 'REPO-SQL\INSTANCE' -Install
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ServerInstance,
 [switch]$Install,
 [switch]$AllowExisting,
 [switch]$TrustServerCertificate
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module SqlServer -ErrorAction Stop
$repoName='DBACentralRepositoryv4'
$root=Split-Path $PSScriptRoot -Parent
$files=@(
 '00_Bootstrap.sql',
 '01_Inventory_Core.sql',
 '02_Patch_Planner.sql',
 '03_Reports.sql',
 '04_Extended_Inventory_And_Diff.sql',
 '05_Retention_Preview.sql',
 '06_FCI_Owner_Observation.sql'
)
if($ServerInstance -match '^(127\.0\.0\.1|localhost|\.)\s*,\s*1543[34]$') {
 throw 'SAFETY STOP: this installer targets a Windows SQL repository, not the Docker LAB ports.'
}
$base=@{
 ServerInstance=$ServerInstance
 Encrypt='Mandatory'
 TrustServerCertificate=[bool]$TrustServerCertificate
 ConnectionTimeout=10
 QueryTimeout=120
 AbortOnError=$true
 ErrorAction='Stop'
}
$master=$base.Clone()
$master['Database']='master'
$master['Query']=@'
SELECT @@SERVERNAME AS ServerName,
 CONVERT(nvarchar(128),SERVERPROPERTY('Edition')) AS Edition,
 CONVERT(nvarchar(40),SERVERPROPERTY('ProductVersion')) AS ProductVersion,
 CONVERT(int,SERVERPROPERTY('IsClustered')) AS IsClustered,
 DB_ID(N'DBACentralRepositoryv4') AS ExistingDbId,
 HAS_PERMS_BY_NAME(NULL,NULL,'CREATE ANY DATABASE') AS CanCreateDatabase;
'@
$identity=Invoke-Sqlcmd @master
Write-Host "Repository target: $ServerInstance"
Write-Host "Connected server: $($identity.ServerName) | edition=$($identity.Edition) | build=$($identity.ProductVersion) | FCI=$($identity.IsClustered)"
Write-Host "Database: $repoName | Exists=$($null -ne $identity.ExistingDbId -and $identity.ExistingDbId -isnot [DBNull])"
if(-not $Install) {
 Write-Host 'PREFLIGHT ONLY: no SQL changes. Review the displayed destination and run with -Install explicitly.'
 return
}
if($null -ne $identity.ExistingDbId -and $identity.ExistingDbId -isnot [DBNull] -and -not $AllowExisting) {
 throw "SAFETY STOP: $repoName already exists. Re-run with -AllowExisting only after verifying it is your v4 repository."
}
if($null -eq $identity.ExistingDbId -or $identity.ExistingDbId -is [DBNull]) {
 if([int]$identity.CanCreateDatabase -ne 1) {
  throw 'Current Windows identity has no CREATE ANY DATABASE permission.'
 }
}
foreach($file in $files) {
 $full=Join-Path $root "sql/$file"
 if(-not (Test-Path -LiteralPath $full)) { throw "Missing SQL file: $full" }
 Write-Host "Installing $file on $ServerInstance..."
 $args=$base.Clone()
 $args['Database']=if($file -eq '00_Bootstrap.sql') {'master'} else {$repoName}
 $args['InputFile']=$full
 [void](Invoke-Sqlcmd @args)
}
$check=$base.Clone()
$check['Database']=$repoName
$check['Query']=@'
SELECT DB_NAME() AS DatabaseName,
 OBJECT_ID(N'inventory.ScanRun',N'U') AS ScanRunTableId,
 OBJECT_ID(N'inventory.FciOwnerObservation',N'U') AS FciOwnerTableId,
 OBJECT_ID(N'inventory.usp_RecordFciObservation',N'P') AS FciProcedureId,
 OBJECT_ID(N'report.vFciOwnerHistory',N'V') AS FciHistoryViewId;
'@
$result=Invoke-Sqlcmd @check
$result | Format-Table -AutoSize
if($null -eq $result.ScanRunTableId -or $result.ScanRunTableId -is [DBNull] -or
   $null -eq $result.FciOwnerTableId -or $result.FciOwnerTableId -is [DBNull] -or
   $null -eq $result.FciProcedureId -or $result.FciProcedureId -is [DBNull]) {
 throw 'Installation incomplete: expected objects are missing.'
}
Write-Host 'PASS: Windows SQL repository installed. No collector jobs, no failover, no production source modifications.'
