<#
.SYNOPSIS
  Eksportuje high-risk uprawnienia w bazach + orphaned users do CSV.
  - ORPHANED_USER: user bez mapowania SID -> login na serwerze
  - DANGEROUS_ROLE_MEMBER: db_owner/db_securityadmin/db_accessadmin/db_ddladmin
  - EXPLICIT_PERMISSION: CONTROL, IMPERSONATE, ALTER ANY USER/ROLE/SCHEMA/ASSEMBLY, TAKE OWNERSHIP, VIEW DEFINITION, ALTER, EXECUTE, UNSAFE ASSEMBLY

  Kompatybilne z różnymi wersjami Invoke-Sqlcmd (Encrypt: bool vs Mandatory/Optional/Strict).

.USAGE
  .\Export-DbHighRiskPermissions.ps1 -ConfigPath .\config.json
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
. "$PSScriptRoot\SqlInventory.Helpers.ps1"
function Ensure-Folder([string]$Path){ Ensure-InvFolder -Path $Path }

function Ensure-SqlServerModule(){ Ensure-InvSqlServerModule }

function Add-EncryptParamsCompat([hashtable]$ConnParams,[pscustomobject]$ServerCfg){ Add-InvEncryptParamsCompat -ConnParams $ConnParams -ServerCfg $ServerCfg }

function New-ConnParamsFromConfig($ServerCfg,$RootCfg){ New-InvSqlConnParams -ServerCfg $ServerCfg -Config $RootCfg -Database 'master' }

Ensure-SqlServerModule

if(-not (Test-Path -LiteralPath $ConfigPath)){
  throw "Nie znaleziono configu: $ConfigPath"
}

$config=(Get-Content -Raw -LiteralPath $ConfigPath) | ConvertFrom-Json

if(-not $config.options){ $config | Add-Member options ([pscustomobject]@{}) }
if($null -eq $config.options.commandTimeoutSeconds){ $config.options | Add-Member commandTimeoutSeconds 60 }
if($null -eq $config.options.includeSystemDbs){ $config.options | Add-Member includeSystemDbs $false }

if(-not $config.output){ $config | Add-Member output ([pscustomobject]@{}) }
if(-not $config.output.folder){ $config.output | Add-Member folder "C:\temp\SqlInventory" }
if(-not $config.output.fileNameHighRisk){ $config.output | Add-Member fileNameHighRisk "sql-db-highrisk-permissions.csv" }

Ensure-Folder $config.output.folder

$outPath = Join-Path $config.output.folder $config.output.fileNameHighRisk

# Budujemy filtr DB bez zmiennych T-SQL
$whereDb = if([bool]$config.options.includeSystemDbs){
  "1=1"
} else {
  "database_id > 4"
}

$dbListQuery = @"
SET NOCOUNT ON;
SELECT name
FROM sys.databases
WHERE state_desc='ONLINE'
  AND $whereDb
ORDER BY name;
"@

$perDbQuery = @"
SET NOCOUNT ON;
DECLARE @db sysname = DB_NAME();

-- 1) orphaned users (brak loginu na serwerze dla SID)
SELECT
  @@SERVERNAME AS SqlServerName,
  @db AS DatabaseName,
  'ORPHANED_USER' AS FindingType,
  dp.name AS PrincipalName,
  dp.type_desc AS PrincipalType,
  NULL AS RoleName,
  NULL AS PermissionName,
  NULL AS PermissionState,
  NULL AS Securable,
  CONVERT(varchar(130), dp.sid, 1) AS PrincipalSidHex
FROM sys.database_principals dp
LEFT JOIN sys.server_principals sp ON sp.sid = dp.sid
WHERE dp.type IN ('S','U','G')
  AND dp.name NOT IN ('dbo','guest','INFORMATION_SCHEMA','sys')
  AND sp.sid IS NULL

UNION ALL

-- 2) dangerous role members
SELECT
  @@SERVERNAME AS SqlServerName,
  @db AS DatabaseName,
  'DANGEROUS_ROLE_MEMBER' AS FindingType,
  m.name AS PrincipalName,
  m.type_desc AS PrincipalType,
  r.name AS RoleName,
  NULL AS PermissionName,
  NULL AS PermissionState,
  NULL AS Securable,
  CONVERT(varchar(130), m.sid, 1) AS PrincipalSidHex
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name IN ('db_owner','db_securityadmin','db_accessadmin','db_ddladmin')

UNION ALL

-- 3) explicit high-risk perms
SELECT
  @@SERVERNAME AS SqlServerName,
  @db AS DatabaseName,
  'EXPLICIT_PERMISSION' AS FindingType,
  grantee.name AS PrincipalName,
  grantee.type_desc AS PrincipalType,
  NULL AS RoleName,
  perm.permission_name AS PermissionName,
  perm.state_desc AS PermissionState,
  perm.class_desc AS Securable,
  CONVERT(varchar(130), grantee.sid, 1) AS PrincipalSidHex
FROM sys.database_permissions perm
JOIN sys.database_principals grantee ON grantee.principal_id = perm.grantee_principal_id
WHERE grantee.type IN ('S','U','G')
  AND perm.permission_name IN (
    'CONTROL','ALTER ANY USER','ALTER ANY ROLE','ALTER ANY SCHEMA','ALTER ANY ASSEMBLY',
    'IMPERSONATE','TAKE OWNERSHIP','VIEW DEFINITION','ALTER','EXECUTE','UNSAFE ASSEMBLY'
  );
"@

$all = New-Object System.Collections.Generic.List[object]

foreach($sv in $config.servers){
  $endpoint = [string]$sv.name
  $alias = if($sv.alias){[string]$sv.alias}else{$endpoint}

  Write-Host ("==> [{0}] High-risk permissions..." -f $endpoint)

  try{
    $conn = New-ConnParamsFromConfig $sv $config
    $dbs = Invoke-Sqlcmd @conn -Query $dbListQuery

    foreach($db in $dbs){
      $dbName = [string]$db.name
      $connDb = $conn.Clone()
      $connDb.Database = $dbName

      try{
        $rows = Invoke-Sqlcmd @connDb -Query $perDbQuery
        foreach($r in $rows){
          $all.Add([pscustomobject]@{
            ServerAlias=$alias
            ServerEndpoint=$endpoint
            SqlServerName=$r.SqlServerName
            DatabaseName=$r.DatabaseName
            FindingType=$r.FindingType
            PrincipalName=$r.PrincipalName
            PrincipalType=$r.PrincipalType
            RoleName=$r.RoleName
            PermissionName=$r.PermissionName
            PermissionState=$r.PermissionState
            Securable=$r.Securable
            PrincipalSidHex=$r.PrincipalSidHex
          }) | Out-Null
        }
      } catch {
        Write-Warning ("Błąd DB {0} na {1}: {2}" -f $dbName, $endpoint, $_.Exception.Message)
      }
    }
  } catch {
    Write-Warning ("Błąd {0}: {1}" -f $endpoint, $_.Exception.Message)
  }
}

$all | Sort-Object FindingType, ServerAlias, DatabaseName, PrincipalName |
  Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8

Write-Host "OK -> $outPath"

