<#
.SYNOPSIS
  Eksportuje inventory Linked Servers do CSV na podstawie config.json.

.REQUIREMENTS
  - Windows PowerShell 5.1+ lub PowerShell 7+
  - Moduł SqlServer (Invoke-Sqlcmd)

.USAGE
  .\Export-LinkedServersInventory.ps1 -ConfigPath .\config.json
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Folder {
  param([Parameter(Mandatory=$true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Ensure-SqlServerModule {
  if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    throw "Brak modułu 'SqlServer'. Zainstaluj: Install-Module SqlServer -Scope CurrentUser"
  }
}

function New-ConnParamsFromConfig {
  param(
    [Parameter(Mandatory=$true)][pscustomobject]$ServerCfg,
    [Parameter(Mandatory=$true)][pscustomobject]$RootCfg
  )

  $p = @{
    ServerInstance  = [string]$ServerCfg.name
    Database        = "master"
    QueryTimeout    = [int]$RootCfg.options.commandTimeoutSeconds
    ErrorAction     = "Stop"
  }

  if ($null -ne $ServerCfg.encrypt) { $p.Encrypt = [bool]$ServerCfg.encrypt }
  if ($null -ne $ServerCfg.trustServerCertificate) { $p.TrustServerCertificate = [bool]$ServerCfg.trustServerCertificate }

  switch ($RootCfg.auth.mode) {
    "Windows" { }
    "SqlLogin" {
      if (-not $RootCfg.auth.user -or -not $RootCfg.auth.password) {
        throw "auth.mode=SqlLogin wymaga auth.user i auth.password."
      }
      $sec = ConvertTo-SecureString $RootCfg.auth.password -AsPlainText -Force
      $p.Username = [string]$RootCfg.auth.user
      $p.Password = $sec
    }
    default { throw "Nieznany auth.mode: $($RootCfg.auth.mode). Użyj: Windows albo SqlLogin." }
  }

  return $p
}

Ensure-SqlServerModule

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "Nie znaleziono configu: $ConfigPath"
}

$config = (Get-Content -LiteralPath $ConfigPath -Raw) | ConvertFrom-Json

# Defaults
if (-not $config.options) { $config | Add-Member -NotePropertyName options -NotePropertyValue ([pscustomobject]@{}) }
if ($null -eq $config.options.commandTimeoutSeconds) { $config.options | Add-Member commandTimeoutSeconds 60 }
if (-not $config.output) { $config | Add-Member -NotePropertyName output -NotePropertyValue ([pscustomobject]@{}) }
if (-not $config.output.folder) { $config.output | Add-Member folder "C:\temp\SqlInventory" }
if (-not $config.output.fileNameLinkedServers) { $config.output | Add-Member fileNameLinkedServers "sql-linked-servers-inventory.csv" }
if ($null -eq $config.output.perServerCsv) { $config.output | Add-Member perServerCsv $false }

Ensure-Folder -Path $config.output.folder

$logPath = Join-Path $config.output.folder ("linkedservers-inventory-log-{0}.txt" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
Start-Transcript -Path $logPath | Out-Null

# 1 wiersz = 1 mapping loginowy (jeśli brak mappingów, nadal będzie 1 wiersz na linked server przez LEFT JOIN)
$query = @"
SET NOCOUNT ON;

;WITH LS AS (
  SELECT
    @@SERVERNAME AS SqlServerName,
    s.server_id,
    s.name AS LinkedServerName,
    s.product,
    s.provider,
    s.data_source,
    s.location,
    s.provider_string,
    s.catalog,
    s.is_linked,
    s.is_remote_login_enabled
  FROM sys.servers s
  WHERE s.is_linked = 1
),
Opt AS (
  SELECT
    o.server_id,
    RPCOut = MAX(CASE WHEN o.name = 'rpc out' THEN o.value_in_use END),
    DataAccess = MAX(CASE WHEN o.name = 'data access' THEN o.value_in_use END),
    CollationCompatible = MAX(CASE WHEN o.name = 'collation compatible' THEN o.value_in_use END),
    UsesRemoteCollation = MAX(CASE WHEN o.name = 'use remote collation' THEN o.value_in_use END),
    RemoteProcTransPromotion = MAX(CASE WHEN o.name = 'remote proc transaction promotion' THEN o.value_in_use END),
    ConnectTimeout = MAX(CASE WHEN o.name = 'connect timeout' THEN o.value_in_use END),
    QueryTimeout = MAX(CASE WHEN o.name = 'query timeout' THEN o.value_in_use END)
  FROM sys.server_options o
  GROUP BY o.server_id
),
Map AS (
  SELECT
    l.server_id,
    LocalPrincipal = CASE WHEN l.local_principal_id = 0 THEN 'ALL_LOGINS' ELSE sp.name END,
    l.local_principal_id,
    l.uses_self_credential,
    l.is_disabled,
    RemoteName = l.remote_name
  FROM sys.linked_logins l
  LEFT JOIN sys.server_principals sp
    ON sp.principal_id = l.local_principal_id
)
SELECT
  ls.SqlServerName,
  ls.LinkedServerName,
  ls.product AS Product,
  ls.provider AS Provider,
  ls.data_source AS DataSource,
  ls.location AS Location,
  ls.provider_string AS ProviderString,
  ls.catalog AS Catalog,
  ls.is_remote_login_enabled AS IsRemoteLoginEnabled,

  ISNULL(o.RPCOut, 0) AS RpcOut,
  ISNULL(o.DataAccess, 0) AS DataAccess,
  ISNULL(o.CollationCompatible, 0) AS CollationCompatible,
  ISNULL(o.UsesRemoteCollation, 0) AS UsesRemoteCollation,
  ISNULL(o.RemoteProcTransPromotion, 0) AS RemoteProcTransactionPromotion,
  o.ConnectTimeout,
  o.QueryTimeout,

  m.LocalPrincipal,
  m.local_principal_id AS LocalPrincipalId,
  m.uses_self_credential AS UsesSelfCredential,
  m.is_disabled AS MappingDisabled,
  m.RemoteName AS RemoteUserName,

  CASE
    WHEN m.server_id IS NULL THEN 'WARN:no_login_mappings'
    WHEN m.local_principal_id = 0 THEN 'WARN:default_mapping_ALL_LOGINS'
    WHEN m.uses_self_credential = 1 THEN 'INFO:uses_self'
    ELSE 'OK'
  END AS MappingStatus,

  CASE
    WHEN ISNULL(o.RPCOut,0) = 1 THEN 'WARN:rpc_out_enabled'
    ELSE 'OK'
  END AS RpcOutStatus

FROM LS ls
LEFT JOIN Opt o
  ON o.server_id = ls.server_id
LEFT JOIN Map m
  ON m.server_id = ls.server_id
ORDER BY
  ls.SqlServerName, ls.LinkedServerName, m.local_principal_id;
"@

$all = New-Object System.Collections.Generic.List[object]

foreach ($sv in $config.servers) {
  $serverEndpoint = [string]$sv.name
  $alias = if ($sv.alias) { [string]$sv.alias } else { $serverEndpoint }

  Write-Host ("==> [{0}] Pobieram linked servers..." -f $serverEndpoint)

  try {
    $conn = New-ConnParamsFromConfig -ServerCfg $sv -RootCfg $config
    $rows = Invoke-Sqlcmd @conn -Query $query

    foreach ($r in $rows) {
      $obj = [PSCustomObject]@{
        ServerAlias    = $alias
        ServerEndpoint = $serverEndpoint
        SqlServerName  = $r.SqlServerName

        LinkedServerName = $r.LinkedServerName
        Product          = $r.Product
        Provider         = $r.Provider
        DataSource       = $r.DataSource
        Location         = $r.Location
        ProviderString   = $r.ProviderString
        Catalog          = $r.Catalog
        IsRemoteLoginEnabled = $r.IsRemoteLoginEnabled

        RpcOut           = $r.RpcOut
        DataAccess       = $r.DataAccess
        CollationCompatible = $r.CollationCompatible
        UsesRemoteCollation = $r.UsesRemoteCollation
        RemoteProcTransactionPromotion = $r.RemoteProcTransactionPromotion
        ConnectTimeout   = $r.ConnectTimeout
        QueryTimeout     = $r.QueryTimeout

        LocalPrincipal   = $r.LocalPrincipal
        LocalPrincipalId = $r.LocalPrincipalId
        UsesSelfCredential = $r.UsesSelfCredential
        MappingDisabled  = $r.MappingDisabled
        RemoteUserName   = $r.RemoteUserName

        MappingStatus    = $r.MappingStatus
        RpcOutStatus     = $r.RpcOutStatus

        Recommendation = if ($r.MappingStatus -like 'WARN:*' -or $r.RpcOut -eq 1) {
          "Review linked server security: avoid ALL_LOGINS mapping; consider disabling RPC OUT; verify least privilege."
        } else {
          "OK"
        }
      }
      $all.Add($obj) | Out-Null
    }

    if ([bool]$config.output.perServerCsv) {
      $safe = ($alias -replace '[^\w\.-]', '_')
      $perPath = Join-Path $config.output.folder ("sql-linked-servers-inventory-{0}.csv" -f $safe)
      $all | Where-Object { $_.ServerAlias -eq $alias } |
        Sort-Object RpcOutStatus, MappingStatus, LinkedServerName, LocalPrincipal |
        Export-Csv -LiteralPath $perPath -NoTypeInformation -Encoding UTF8
      Write-Host ("    -> Zapisano per-serwer CSV: {0}" -f $perPath)
    }

    Write-Host ("    OK: {0} wierszy (linked×mappings)" -f ($rows.Count))
  }
  catch {
    Write-Warning ("    BŁĄD na serwerze [{0}]: {1}" -f $serverEndpoint, $_.Exception.Message)
    continue
  }
}

$outPath = Join-Path $config.output.folder $config.output.fileNameLinkedServers

# Najpierw RPC OUT i mapping WARN, potem reszta
$all |
  Sort-Object RpcOutStatus, MappingStatus, ServerAlias, LinkedServerName, LocalPrincipal |
  Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host ("Zbiorczy CSV: {0}" -f $outPath)
Write-Host ("Log (transcript): {0}" -f $logPath)

Stop-Transcript | Out-Null
