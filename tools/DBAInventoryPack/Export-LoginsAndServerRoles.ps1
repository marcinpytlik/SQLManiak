[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ConfigPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
if(-not $config.output){ $config | Add-Member output ([pscustomobject]@{}) }
if(-not $config.output.folder){ $config.output | Add-Member folder "C:\temp\SqlInventory" }
Ensure-Folder $config.output.folder

$outPath = Join-Path $config.output.folder "sql-logins-serverroles.csv"

$query = @"
SET NOCOUNT ON;

;WITH Roles AS (
  SELECT
    m.member_principal_id,
    ServerRoles = STRING_AGG(r.name, '; ') WITHIN GROUP (ORDER BY r.name)
  FROM sys.server_role_members m
  JOIN sys.server_principals r ON r.principal_id = m.role_principal_id
  GROUP BY m.member_principal_id
)
SELECT
  @@SERVERNAME AS SqlServerName,
  sp.name AS LoginName,
  sp.type_desc AS LoginType,
  sp.is_disabled AS IsDisabled,
  sp.default_database_name AS DefaultDatabase,
  sp.default_language_name AS DefaultLanguage,
  sp.create_date AS CreateDate,
  sp.modify_date AS ModifyDate,
  ISNULL(r.ServerRoles,'') AS ServerRoles,
  CASE WHEN IS_SRVROLEMEMBER('sysadmin', sp.name) = 1 THEN 1 ELSE 0 END AS IsSysadmin,
  sl.is_policy_checked AS IsPolicyChecked,
  sl.is_expiration_checked AS IsExpirationChecked
FROM sys.server_principals sp
LEFT JOIN sys.sql_logins sl ON sl.principal_id = sp.principal_id
LEFT JOIN Roles r ON r.member_principal_id = sp.principal_id
WHERE sp.type IN ('S','U','G')
  AND sp.name NOT LIKE '##%##'
ORDER BY sp.name;
"@

$all = New-Object System.Collections.Generic.List[object]

foreach($sv in $config.servers){
  $endpoint=[string]$sv.name
  $alias= if($sv.alias){[string]$sv.alias}else{$endpoint}
  try{
    $conn=New-ConnParamsFromConfig $sv $config
    $rows=Invoke-Sqlcmd @conn -Query $query
    foreach($r in $rows){
      $all.Add([pscustomobject]@{
        ServerAlias=$alias; ServerEndpoint=$endpoint; SqlServerName=$r.SqlServerName
        LoginName=$r.LoginName; LoginType=$r.LoginType; IsDisabled=$r.IsDisabled
        DefaultDatabase=$r.DefaultDatabase; DefaultLanguage=$r.DefaultLanguage
        CreateDate=$r.CreateDate; ModifyDate=$r.ModifyDate
        ServerRoles=$r.ServerRoles; IsSysadmin=$r.IsSysadmin
        IsPolicyChecked=$r.IsPolicyChecked; IsExpirationChecked=$r.IsExpirationChecked
      }) | Out-Null
    }
  } catch {
    Write-Warning "Błąd $endpoint: $($_.Exception.Message)"
  }
}

$all | Sort-Object IsSysadmin -Descending, ServerAlias, LoginName |
  Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8

Write-Host "OK -> $outPath"
