[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ConfigPath)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

function Ensure-Folder([string]$Path){ if(-not(Test-Path $Path)){ New-Item -ItemType Directory -Path $Path | Out-Null } }
function Ensure-SqlServerModule(){ if(-not(Get-Module -ListAvailable -Name SqlServer)){ throw "Brak modułu SqlServer. Install-Module SqlServer -Scope CurrentUser" } }
function New-ConnParamsFromConfig($ServerCfg,$RootCfg){
  $p=@{ ServerInstance=[string]$ServerCfg.name; Database="msdb"; QueryTimeout=[int]$RootCfg.options.commandTimeoutSeconds; ErrorAction="Stop" }
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

$outCred = Join-Path $config.output.folder "sql-credentials.csv"
$outProxy= Join-Path $config.output.folder "sql-agent-proxies.csv"
$outPerm = Join-Path $config.output.folder "sql-agent-proxy-permissions.csv"

$qCred=@"
SET NOCOUNT ON;
SELECT
  @@SERVERNAME AS SqlServerName,
  credential_id AS CredentialId,
  name AS CredentialName,
  credential_identity AS CredentialIdentity,
  create_date AS CreateDate,
  modify_date AS ModifyDate
FROM sys.credentials
ORDER BY name;
"@

$qProxy=@"
SET NOCOUNT ON;
SELECT
  @@SERVERNAME AS SqlServerName,
  p.proxy_id AS ProxyId,
  p.name AS ProxyName,
  p.credential_id AS CredentialId,
  c.name AS CredentialName,
  c.credential_identity AS CredentialIdentity,
  p.enabled AS Enabled,
  p.description AS Description
FROM msdb.dbo.sysproxies p
LEFT JOIN sys.credentials c ON c.credential_id = p.credential_id
ORDER BY p.name;
"@

$qPerm=@"
SET NOCOUNT ON;
SELECT
  @@SERVERNAME AS SqlServerName,
  p.name AS ProxyName,
  s.subsystem AS Subsystem,
  sp.name AS GrantedToLogin
FROM msdb.dbo.sysproxies p
JOIN msdb.dbo.sysproxysubsystem ps ON ps.proxy_id = p.proxy_id
JOIN msdb.dbo.syssubsystems s ON s.subsystem_id = ps.subsystem_id
JOIN msdb.dbo.sysproxylogin pl ON pl.proxy_id = p.proxy_id
JOIN sys.server_principals sp ON sp.sid = pl.sid
ORDER BY p.name, s.subsystem, sp.name;
"@

$credAll=New-Object System.Collections.Generic.List[object]
$proxyAll=New-Object System.Collections.Generic.List[object]
$permAll=New-Object System.Collections.Generic.List[object]

foreach($sv in $config.servers){
  $endpoint=[string]$sv.name
  $alias= if($sv.alias){[string]$sv.alias}else{$endpoint}
  try{
    $conn=New-ConnParamsFromConfig $sv $config

    foreach($r in (Invoke-Sqlcmd @conn -Query $qCred)){
      $credAll.Add([pscustomobject]@{
        ServerAlias=$alias; ServerEndpoint=$endpoint; SqlServerName=$r.SqlServerName
        CredentialId=$r.CredentialId; CredentialName=$r.CredentialName; CredentialIdentity=$r.CredentialIdentity
        CreateDate=$r.CreateDate; ModifyDate=$r.ModifyDate
      })|Out-Null
    }

    foreach($r in (Invoke-Sqlcmd @conn -Query $qProxy)){
      $proxyAll.Add([pscustomobject]@{
        ServerAlias=$alias; ServerEndpoint=$endpoint; SqlServerName=$r.SqlServerName
        ProxyId=$r.ProxyId; ProxyName=$r.ProxyName; Enabled=$r.Enabled
        CredentialId=$r.CredentialId; CredentialName=$r.CredentialName; CredentialIdentity=$r.CredentialIdentity
        Description=$r.Description
      })|Out-Null
    }

    foreach($r in (Invoke-Sqlcmd @conn -Query $qPerm)){
      $permAll.Add([pscustomobject]@{
        ServerAlias=$alias; ServerEndpoint=$endpoint; SqlServerName=$r.SqlServerName
        ProxyName=$r.ProxyName; Subsystem=$r.Subsystem; GrantedToLogin=$r.GrantedToLogin
      })|Out-Null
    }

  } catch {
    Write-Warning "Błąd $endpoint: $($_.Exception.Message)"
  }
}

$credAll | Sort-Object ServerAlias, CredentialName | Export-Csv -LiteralPath $outCred -NoTypeInformation -Encoding UTF8
$proxyAll| Sort-Object ServerAlias, ProxyName | Export-Csv -LiteralPath $outProxy -NoTypeInformation -Encoding UTF8
$permAll | Sort-Object ServerAlias, ProxyName, Subsystem, GrantedToLogin | Export-Csv -LiteralPath $outPerm -NoTypeInformation -Encoding UTF8

Write-Host "OK -> $outCred"
Write-Host "OK -> $outProxy"
Write-Host "OK -> $outPerm"
