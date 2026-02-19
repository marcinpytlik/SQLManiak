[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ConfigPath)

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

# output folder + filename (bez wymagania dodatkowych properties)
$outFolder = "C:\temp\SqlInventory"
if ($config.output -and $config.output.folder) { $outFolder = [string]$config.output.folder }
Ensure-Folder $outFolder

$outPath = Join-Path $outFolder "sql-instance-baseline.csv"

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
    Write-Warning ("Błąd {0}: {1}" -f $endpoint, $_.Exception.Message)
  }
}

$all | Sort-Object ServerAlias, RowType, Name |
  Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8

Write-Host ("OK -> {0}" -f $outPath)