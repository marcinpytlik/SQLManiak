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
if(-not $config.output){ $config | Add-Member output ([pscustomobject]@{}) }
if(-not $config.output.folder){ $config.output | Add-Member folder "C:\temp\SqlInventory" }
Ensure-Folder $config.output.folder

$outPath = Join-Path $config.output.folder "sql-instance-baseline.csv"

$query=@"
SET NOCOUNT ON;

SELECT
  @@SERVERNAME AS SqlServerName,
  'SERVERPROPERTY' AS RowType,
  v.PropName,
  v.PropValue,
  NULL AS IsDynamic,
  NULL AS ConfigValue,
  NULL AS RunValue
FROM (VALUES
 ('MachineName', CAST(SERVERPROPERTY('MachineName') AS nvarchar(4000))),
 ('ServerName', CAST(SERVERPROPERTY('ServerName') AS nvarchar(4000))),
 ('InstanceName', CAST(SERVERPROPERTY('InstanceName') AS nvarchar(4000))),
 ('Edition', CAST(SERVERPROPERTY('Edition') AS nvarchar(4000))),
 ('ProductVersion', CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(4000))),
 ('ProductLevel', CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(4000))),
 ('ProductUpdateLevel', CAST(SERVERPROPERTY('ProductUpdateLevel') AS nvarchar(4000))),
 ('ProductUpdateReference', CAST(SERVERPROPERTY('ProductUpdateReference') AS nvarchar(4000))),
 ('IsClustered', CAST(SERVERPROPERTY('IsClustered') AS nvarchar(4000))),
 ('IsHadrEnabled', CAST(SERVERPROPERTY('IsHadrEnabled') AS nvarchar(4000)))
) v(PropName, PropValue)

UNION ALL

SELECT
  @@SERVERNAME AS SqlServerName,
  'SP_CONFIGURE' AS RowType,
  c.name AS PropName,
  CAST(c.value_in_use AS nvarchar(4000)) AS PropValue,
  c.is_dynamic AS IsDynamic,
  c.value AS ConfigValue,
  c.value_in_use AS RunValue
FROM sys.configurations c
WHERE c.name IN (
 'max server memory (MB)','min server memory (MB)',
 'max degree of parallelism','cost threshold for parallelism',
 'backup compression default',
 'xp_cmdshell','clr enabled','contained database authentication',
 'Ad Hoc Distributed Queries','remote access','show advanced options',
 'blocked process threshold (s)','optimize for ad hoc workloads',
 'Database Mail XPs','cross db ownership chaining'
)
ORDER BY RowType, PropName;
"@

$all=New-Object System.Collections.Generic.List[object]
foreach($sv in $config.servers){
  $endpoint=[string]$sv.name
  $alias= if($sv.alias){[string]$sv.alias}else{$endpoint}
  try{
    $conn=New-ConnParamsFromConfig $sv $config
    $rows=Invoke-Sqlcmd @conn -Query $query
    foreach($r in $rows){
      $all.Add([pscustomobject]@{
        ServerAlias=$alias; ServerEndpoint=$endpoint; SqlServerName=$r.SqlServerName
        RowType=$r.RowType; Name=$r.PropName; Value=$r.PropValue
        IsDynamic=$r.IsDynamic; ConfigValue=$r.ConfigValue; RunValue=$r.RunValue
      })|Out-Null
    }
  } catch {
    Write-Warning "Błąd $endpoint: $($_.Exception.Message)"
  }
}

$all | Sort-Object ServerAlias, RowType, Name |
  Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8

Write-Host "OK -> $outPath"
