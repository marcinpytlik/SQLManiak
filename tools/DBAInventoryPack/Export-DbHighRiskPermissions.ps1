[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ConfigPath)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

function Ensure-Folder([string]$Path){ if(-not(Test-Path $Path)){ New-Item -ItemType Directory -Path $Path | Out-Null } }
function Ensure-SqlServerModule(){ if(-not(Get-Module -ListAvailable -Name SqlServer)){ throw "Brak modułu SqlServer. Install-Module SqlServer -Scope CurrentUser" } }
function New-ConnParamsFromConfig($ServerCfg,$RootCfg){
  $p=@{ ServerInstance=[string]$ServerCfg.name; Database="master"; QueryTimeout=[int]$RootCfg.options.commandTimeoutSeconds; ErrorAction="Stop" }
  if($null -ne $ServerCfg.encrypt){ $p.Encrypt=[bool]$ServerCfg.encrypt }
  if($null -ne $ServerCfg.trustServerCertificate){ $p.TrustServerCertificate=[bool]$ServerCfg.trustServerCertificate }
  switch($RootCfg.auth.mode){
    "Windows" { }
    "SqlLogin" {
      $sec=ConvertTo-SecureString $RootCfg.auth.password -AsPlainText -Force
      $p.Username=[string]$RootCfg.auth.user; $p.Password=$sec
    }
    default { throw "Nieznany auth.mode: $($RootCfg.auth.mode)" }
  }
  $p
}

Ensure-SqlServerModule
$config=(Get-Content -Raw -LiteralPath $ConfigPath) | ConvertFrom-Json
if(-not $config.options){ $config | Add-Member options ([pscustomobject]@{}) }
if($null -eq $config.options.commandTimeoutSeconds){ $config.options | Add-Member commandTimeoutSeconds 60 }
if($null -eq $config.options.includeSystemDbs){ $config.options | Add-Member includeSystemDbs $false }
if(-not $config.output){ $config | Add-Member output ([pscustomobject]@{}) }
if(-not $config.output.folder){ $config.output | Add-Member folder "C:\temp\SqlInventory" }
Ensure-Folder $config.output.folder

$outPath = Join-Path $config.output.folder "sql-db-highrisk-permissions.csv"

$dbListQuery = @"
SET NOCOUNT ON;
SELECT name, database_id
FROM sys.databases
WHERE state_desc='ONLINE'
  AND (@IncludeSystem=1 OR database_id > 4)
ORDER BY name;
"@

$perDbQuery = @"
SET NOCOUNT ON;

DECLARE @db sysname = DB_NAME();

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

SELECT
  @@SERVERNAME AS SqlServerName,
  @db AS DatabaseName,
  'DANGEROUS_ROLE_MEMBER' AS FindingType,
  m.name AS PrincipalName,
  m.type_desc AS PrincipalType,
  r.name AS RoleName,
  NULL,NULL,NULL,NULL,
  CONVERT(varchar(130), m.sid, 1)
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name IN ('db_owner','db_securityadmin','db_accessadmin','db_ddladmin')

UNION ALL

SELECT
  @@SERVERNAME AS SqlServerName,
  @db AS DatabaseName,
  'EXPLICIT_PERMISSION' AS FindingType,
  grantee.name AS PrincipalName,
  grantee.type_desc AS PrincipalType,
  NULL AS RoleName,
  perm.permission_name AS PermissionName,
  perm.state_desc AS PermissionState,
  CASE
    WHEN perm.class_desc = 'DATABASE' THEN 'DATABASE'
    WHEN perm.class_desc IN ('OBJECT_OR_COLUMN','SCHEMA') THEN perm.class_desc
    ELSE perm.class_desc
  END AS Securable,
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
  $endpoint=[string]$sv.name
  $alias= if($sv.alias){[string]$sv.alias}else{$endpoint}

  try{
    $conn=New-ConnParamsFromConfig $sv $config
    $includeSystem = if([bool]$config.options.includeSystemDbs){1}else{0}
    $dbs = Invoke-Sqlcmd @conn -Query $dbListQuery -Variable @{ IncludeSystem = $includeSystem }

    foreach($db in $dbs){
      $connDb = $conn.Clone()
      $connDb.Database = [string]$db.name
      try{
        $rows = Invoke-Sqlcmd @connDb -Query $perDbQuery
        foreach($r in $rows){
          $all.Add([pscustomobject]@{
            ServerAlias=$alias; ServerEndpoint=$endpoint; SqlServerName=$r.SqlServerName
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
        Write-Warning "Błąd DB $($db.name) na $endpoint: $($_.Exception.Message)"
      }
    }
  } catch {
    Write-Warning "Błąd $endpoint: $($_.Exception.Message)"
  }
}

$all | Sort-Object FindingType, ServerAlias, DatabaseName, PrincipalName |
  Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8

Write-Host "OK -> $outPath"
