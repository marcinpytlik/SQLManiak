<#
.SYNOPSIS
  Eksport inventory baz danych do CSV (1 wiersz = 1 DB):
  - podstawowe ustawienia
  - owner (SUSER_SNAME(owner_sid) + sid hex + status)
  - rozmiary data/log/total (z sys.master_files)

  Kompatybilne z różnymi wersjami Invoke-Sqlcmd (Encrypt: bool vs Mandatory/Optional/Strict).

.USAGE
  .\Export-SqlDbInventory.ps1 -ConfigPath .\config.json
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Folder([string]$Path){
  if(-not(Test-Path -LiteralPath $Path)){
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Ensure-SqlServerModule(){
  if(-not(Get-Module -ListAvailable -Name SqlServer)){
    throw "Brak modułu 'SqlServer'. Zainstaluj: Install-Module SqlServer -Scope CurrentUser"
  }
}

function Add-EncryptParamsCompat {
  param(
    [Parameter(Mandatory=$true)][hashtable]$ConnParams,
    [Parameter(Mandatory=$true)][pscustomobject]$ServerCfg
  )

  $invoke = Get-Command Invoke-Sqlcmd -ErrorAction Stop

  $encryptParam = $invoke.Parameters['Encrypt']
  if ($encryptParam -and $null -ne $ServerCfg.encrypt) {
    $encryptRaw = $ServerCfg.encrypt

    $validateSet = $encryptParam.Attributes |
      Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
      Select-Object -First 1

    if ($validateSet) {
      # Mandatory|Optional|Strict
      if ($encryptRaw -is [string]) {
        $ConnParams.Encrypt = $encryptRaw
      } else {
        # bool -> sensowny default
        $ConnParams.Encrypt = "Optional"
      }
    } else {
      # bool
      $ConnParams.Encrypt = [bool]$encryptRaw
    }
  }

  $tscParam = $invoke.Parameters['TrustServerCertificate']
  if ($tscParam -and $null -ne $ServerCfg.trustServerCertificate) {
    $ConnParams.TrustServerCertificate = [bool]$ServerCfg.trustServerCertificate
  }
}

function New-ConnParamsFromConfig($ServerCfg,$RootCfg){
  $p=@{
    ServerInstance=[string]$ServerCfg.name
    Database="master"
    QueryTimeout=[int]$RootCfg.options.commandTimeoutSeconds
    ErrorAction="Stop"
  }

  switch($RootCfg.auth.mode){
    "Windows" { }
    "SqlLogin" {
      if(-not $RootCfg.auth.user -or -not $RootCfg.auth.password){
        throw "auth.mode=SqlLogin wymaga auth.user i auth.password."
      }
      $sec = ConvertTo-SecureString $RootCfg.auth.password -AsPlainText -Force
      $p.Username=[string]$RootCfg.auth.user
      $p.Password=$sec
    }
    default { throw "Nieznany auth.mode: $($RootCfg.auth.mode). Użyj Windows albo SqlLogin." }
  }

  Add-EncryptParamsCompat -ConnParams $p -ServerCfg $ServerCfg
  return $p
}

Ensure-SqlServerModule

if(-not (Test-Path -LiteralPath $ConfigPath)){ throw "Nie znaleziono configu: $ConfigPath" }
$config = (Get-Content -Raw -LiteralPath $ConfigPath) | ConvertFrom-Json

# defaults
if(-not $config.options){ $config | Add-Member options ([pscustomobject]@{}) }
if($null -eq $config.options.commandTimeoutSeconds){ $config.options | Add-Member commandTimeoutSeconds 60 }
if($null -eq $config.options.includeSystemDbs){ $config.options | Add-Member includeSystemDbs $true }

if(-not $config.output){ $config | Add-Member output ([pscustomobject]@{}) }
if(-not $config.output.folder){ $config.output | Add-Member folder "C:\temp\SqlInventory" }
if(-not $config.output.fileName){ $config.output | Add-Member fileName "sql-db-inventory.csv" }

Ensure-Folder $config.output.folder

$logPath = Join-Path $config.output.folder ("inventory-log-{0}.txt" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
Start-Transcript -Path $logPath | Out-Null

# Budujemy filtr baz bez parametrów T-SQL
$whereClause = if([bool]$config.options.includeSystemDbs){
  "1=1"
} else {
  "d.database_id > 4"
}

$query = @"
SET NOCOUNT ON;

;WITH Files AS (
  SELECT
    d.database_id,
    DataSizeMB  = SUM(CASE WHEN mf.type = 0 THEN mf.size END) * 8.0 / 1024,
    LogSizeMB   = SUM(CASE WHEN mf.type = 1 THEN mf.size END) * 8.0 / 1024,
    TotalSizeMB = SUM(mf.size) * 8.0 / 1024
  FROM sys.databases d
  JOIN sys.master_files mf
    ON mf.database_id = d.database_id
  GROUP BY d.database_id
)
SELECT
  @@SERVERNAME AS SqlServerName,
  d.name       AS DatabaseName,
  d.database_id AS DatabaseId,
  d.state_desc AS StateDesc,
  d.user_access_desc AS UserAccessDesc,
  d.is_read_only AS IsReadOnly,
  d.recovery_model_desc AS RecoveryModel,
  d.compatibility_level AS CompatibilityLevel,
  d.collation_name AS CollationName,
  d.page_verify_option_desc AS PageVerify,
  d.containment_desc AS Containment,

  d.is_auto_close_on AS IsAutoCloseOn,
  d.is_auto_shrink_on AS IsAutoShrinkOn,
  d.is_auto_create_stats_on AS IsAutoCreateStatsOn,
  d.is_auto_update_stats_on AS IsAutoUpdateStatsOn,
  d.is_auto_update_stats_async_on AS IsAutoUpdateStatsAsyncOn,
  d.is_parameterization_forced AS IsParameterizationForced,
  d.is_query_store_on AS IsQueryStoreOn,
  d.is_broker_enabled AS IsBrokerEnabled,
  d.is_trustworthy_on AS IsTrustworthyOn,
  d.is_encrypted AS IsEncrypted,
  d.is_cdc_enabled AS IsCdcEnabled,
  d.is_read_committed_snapshot_on AS IsReadCommittedSnapshotOn,
  d.snapshot_isolation_state_desc AS SnapshotIsolationState,
  d.target_recovery_time_in_seconds AS TargetRecoveryTimeSeconds,

  -- OWNER
  SUSER_SNAME(d.owner_sid) AS OwnerLogin,
  CONVERT(varchar(130), d.owner_sid, 1) AS OwnerSidHex,
  CASE WHEN d.owner_sid = 0x01 THEN 1 ELSE 0 END AS OwnerIsSa,
  CASE
    WHEN d.owner_sid = 0x01 THEN 'OK:sa'
    WHEN SUSER_SNAME(d.owner_sid) IS NULL THEN 'ALERT:orphaned_sid'
    ELSE 'OK'
  END AS OwnerStatus,

  CAST(f.DataSizeMB AS decimal(18,2)) AS DataSizeMB,
  CAST(f.LogSizeMB  AS decimal(18,2)) AS LogSizeMB,
  CAST(f.TotalSizeMB AS decimal(18,2)) AS TotalSizeMB,

  d.create_date AS CreateDate
FROM sys.databases d
LEFT JOIN Files f
  ON f.database_id = d.database_id
WHERE $whereClause
ORDER BY @@SERVERNAME, d.name;
"@

$all = New-Object System.Collections.Generic.List[object]

foreach($s in $config.servers){
  $serverEndpoint=[string]$s.name
  $alias = if($s.alias){[string]$s.alias}else{$serverEndpoint}

  Write-Host ("==> [{0}] Pobieram inventory..." -f $serverEndpoint)

  try{
    $conn = New-ConnParamsFromConfig $s $config
    $rows = Invoke-Sqlcmd @conn -Query $query

    foreach($r in $rows){
      $all.Add([pscustomobject]@{
        ServerAlias=$alias
        ServerEndpoint=$serverEndpoint
        SqlServerName=$r.SqlServerName
        DatabaseName=$r.DatabaseName
        DatabaseId=$r.DatabaseId
        StateDesc=$r.StateDesc
        UserAccessDesc=$r.UserAccessDesc
        IsReadOnly=$r.IsReadOnly
        RecoveryModel=$r.RecoveryModel
        CompatibilityLevel=$r.CompatibilityLevel
        CollationName=$r.CollationName
        PageVerify=$r.PageVerify
        Containment=$r.Containment

        IsAutoCloseOn=$r.IsAutoCloseOn
        IsAutoShrinkOn=$r.IsAutoShrinkOn
        IsAutoCreateStatsOn=$r.IsAutoCreateStatsOn
        IsAutoUpdateStatsOn=$r.IsAutoUpdateStatsOn
        IsAutoUpdateStatsAsyncOn=$r.IsAutoUpdateStatsAsyncOn
        IsParameterizationForced=$r.IsParameterizationForced
        IsQueryStoreOn=$r.IsQueryStoreOn
        IsBrokerEnabled=$r.IsBrokerEnabled
        IsTrustworthyOn=$r.IsTrustworthyOn
        IsEncrypted=$r.IsEncrypted
        IsCdcEnabled=$r.IsCdcEnabled
        IsReadCommittedSnapshotOn=$r.IsReadCommittedSnapshotOn
        SnapshotIsolationState=$r.SnapshotIsolationState
        TargetRecoveryTimeSeconds=$r.TargetRecoveryTimeSeconds

        OwnerLogin=$r.OwnerLogin
        OwnerSidHex=$r.OwnerSidHex
        OwnerIsSa=$r.OwnerIsSa
        OwnerStatus=$r.OwnerStatus

        DataSizeMB=$r.DataSizeMB
        LogSizeMB=$r.LogSizeMB
        TotalSizeMB=$r.TotalSizeMB
        CreateDate=$r.CreateDate
      }) | Out-Null
    }

    Write-Host ("    OK: {0} baz" -f ($rows.Count))
  }
  catch{
    Write-Warning ("    BŁĄD na serwerze [{0}]: {1}" -f $serverEndpoint, $_.Exception.Message)
    continue
  }
}

$outPath = Join-Path $config.output.folder $config.output.fileName

$all | Sort-Object OwnerStatus, ServerAlias, DatabaseName |
  Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host ("Zbiorczy CSV: {0}" -f $outPath)
Write-Host ("Log (transcript): {0}" -f $logPath)

Stop-Transcript | Out-Null
