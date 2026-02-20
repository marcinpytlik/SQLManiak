<# 
.SYNOPSIS
  Checks SQL Server patch compliance (build version) for servers listed in config.json.
  PowerShell 5.1 compatible.

.DESCRIPTION
  - Reads config.json (servers/auth/output/options)
  - Connects to each server, reads ProductVersion/ProductLevel/ProductUpdateLevel
  - Compares with baseline builds (built-in or patch-baseline.json)
  - Writes CSV report to output.folder
  - Adds VersionDelta, Action, RiskScore
  - Generates a separate high-risk CSV (WARN/CRIT)

.PARAMETER ConfigPath
  Path to config.json

.PARAMETER BaselinePath
  Optional path to patch-baseline JSON (overrides built-in baseline)

.PARAMETER OutputFileName
  Optional output file name (default: sql-patch-compliance.csv)

.PARAMETER HighRiskFileName
  Optional high risk output file name (default: sql-patch-compliance-highrisk.csv)
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$ConfigPath,

  [Parameter(Mandatory=$false)]
  [string]$BaselinePath,

  [Parameter(Mandatory=$false)]
  [string]$OutputFileName = "sql-patch-compliance.csv",

  [Parameter(Mandatory=$false)]
  [string]$HighRiskFileName = "sql-patch-compliance-highrisk.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-JsonFile {
  param([Parameter(Mandatory=$true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
  (Get-Content -LiteralPath $Path -Raw) | ConvertFrom-Json
}

function Ensure-Folder {
  param([Parameter(Mandatory=$true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function To-Version {
  param([Parameter(Mandatory=$true)][string]$v)
  try { [version]$v } catch { $null }
}

function Get-DefaultBaseline {
  # Baseline as of 2026-02-20:
  return @{
    "13" = @{ Name="SQL Server 2016"; RecommendedBuild="13.0.6475.1"; RecommendedLabel="SP3 + GDR"; Released="2025-11-11" }
    "15" = @{ Name="SQL Server 2019"; RecommendedBuild="15.0.4455.2"; RecommendedLabel="CU+GDR"; Released="2025-11-11" }
    "16" = @{ Name="SQL Server 2022"; RecommendedBuild="16.0.4236.2"; RecommendedLabel="CU23 (re-release)"; Released="2026-01-29" }
  }
}

function Read-Baseline {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return Get-DefaultBaseline }

  $obj = Read-JsonFile -Path $Path
  if ($null -eq $obj.baseline) { throw "Baseline JSON must contain top-level property 'baseline'." }

  $ht = @{}
  foreach ($p in $obj.baseline.PSObject.Properties) {
    $major = $p.Name
    $val = $p.Value
    $ht[$major] = @{
      Name = $val.Name
      RecommendedBuild = $val.RecommendedBuild
      RecommendedLabel = $val.RecommendedLabel
      Released = $val.Released
    }
  }
  $ht
}

function Normalize-EncryptValue {
  <#
    System.Data.SqlClient (PS 5.1) expects Encrypt=True/False (boolean-like).
    It does NOT accept Optional/Mandatory/Strict.
  #>
  param([string]$Encrypt)
  if ([string]::IsNullOrWhiteSpace($Encrypt)) { return "False" }

  switch ($Encrypt.Trim().ToLowerInvariant()) {
    "true"      { "True" }
    "false"     { "False" }
    "yes"       { "True" }
    "no"        { "False" }
    "optional"  { "False" }
    "mandatory" { "True" }
    "strict"    { "True" }
    default     { "False" }
  }
}

function New-ConnString {
  param(
    [Parameter(Mandatory=$true)][object]$Server,
    [Parameter(Mandatory=$true)][object]$Auth
  )

  $dataSource = $Server.name

  $encryptRaw = $null
  if ($Server.PSObject.Properties.Name -contains "encrypt") { $encryptRaw = [string]$Server.encrypt }
  $encrypt = Normalize-EncryptValue -Encrypt $encryptRaw

  $trust = $false
  if ($Server.PSObject.Properties.Name -contains "trustServerCertificate") { $trust = [bool]$Server.trustServerCertificate }

  $mode = "Windows"
  if ($Auth.PSObject.Properties.Name -contains "mode" -and $Auth.mode) { $mode = [string]$Auth.mode }

  if ($mode -eq "Windows") {
    "Server=$dataSource;Database=master;Integrated Security=True;Encrypt=$encrypt;TrustServerCertificate=$trust;Application Name=DBAInventoryPack-PatchCheck;"
    return
  }

  if ($mode -eq "Sql") {
    if (-not ($Auth.PSObject.Properties.Name -contains "username" -and $Auth.PSObject.Properties.Name -contains "password")) {
      throw "auth.mode=Sql requires auth.username and auth.password in config.json"
    }
    $user = $Auth.username
    $pass = $Auth.password
    "Server=$dataSource;Database=master;User ID=$user;Password=$pass;Encrypt=$encrypt;TrustServerCertificate=$trust;Application Name=DBAInventoryPack-PatchCheck;"
    return
  }

  throw "Unsupported auth.mode: $mode (use Windows or Sql)"
}

function Invoke-SqlQuery {
  param(
    [Parameter(Mandatory=$true)][string]$ConnectionString,
    [Parameter(Mandatory=$true)][string]$Query,
    [int]$TimeoutSeconds = 60
  )

  Add-Type -AssemblyName System.Data
  $conn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)

  try {
    $conn.Open()
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $Query
    $cmd.CommandTimeout = $TimeoutSeconds

    $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $dt = New-Object System.Data.DataTable
    [void]$da.Fill($dt)

    # prevent PowerShell from enumerating DataTable to DataRow[]
    return ,$dt
  }
  finally {
    if ($conn.State -eq "Open") { $conn.Close() }
    $conn.Dispose()
  }
}

function Get-SqlInstanceInfo {
  param(
    [Parameter(Mandatory=$true)][string]$ConnectionString,
    [int]$TimeoutSeconds = 60
  )

  $q = @"
SET NOCOUNT ON;
SELECT
  @@SERVERNAME AS ServerName,
  CAST(SERVERPROPERTY('MachineName') AS nvarchar(128)) AS MachineName,
  CAST(SERVERPROPERTY('InstanceName') AS nvarchar(128)) AS InstanceName,
  CAST(SERVERPROPERTY('Edition') AS nvarchar(128)) AS Edition,
  CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(32)) AS ProductVersion,
  CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(32)) AS ProductLevel,
  CAST(SERVERPROPERTY('ProductUpdateLevel') AS nvarchar(32)) AS ProductUpdateLevel,
  CAST(SERVERPROPERTY('ProductUpdateReference') AS nvarchar(64)) AS ProductUpdateReference,
  CAST(SERVERPROPERTY('ProductMajorVersion') AS int) AS ProductMajorVersion,
  @@VERSION AS VersionBanner;
"@

  $dt = Invoke-SqlQuery -ConnectionString $ConnectionString -Query $q -TimeoutSeconds $TimeoutSeconds
  if ($dt -isnot [System.Data.DataTable]) { throw "Invoke-SqlQuery returned unexpected type: $($dt.GetType().FullName)" }
  if ($dt.Rows.Count -lt 1) { return $null }
  $dt.Rows[0]
}

function Compare-Build {
  param(
    [Parameter(Mandatory=$true)][string]$CurrentBuild,
    [Parameter(Mandatory=$true)][string]$RecommendedBuild
  )

  $cur = To-Version $CurrentBuild
  $rec = To-Version $RecommendedBuild
  if ($null -eq $cur -or $null -eq $rec) { return @{ Status="Unknown"; Compare=0; Cur=$cur; Rec=$rec } }

  if ($cur -ge $rec) { return @{ Status="UpToDate"; Compare=1; Cur=$cur; Rec=$rec } }
  @{ Status="Outdated"; Compare=-1; Cur=$cur; Rec=$rec }
}

function Get-RiskScore {
  param(
    [Parameter(Mandatory=$true)][string]$ProductUpdateLevel,
    [Parameter(Mandatory=$true)][string]$ComplianceStatus
  )

  # Simple, auditable rules:
  # - If cannot determine -> WARN
  # - If Outdated and update level is RTM -> CRIT
  # - If Outdated (but not RTM) -> WARN
  # - If UpToDate -> OK
  if ($ComplianceStatus -eq "UpToDate") { return "OK" }
  if ($ComplianceStatus -eq "Unknown") { return "WARN" }

  $pul = ($ProductUpdateLevel ?? "").Trim().ToUpperInvariant()
  if ($pul -eq "RTM") { return "CRIT" }

  # If ProductUpdateLevel empty, but outdated -> WARN (still needs patch)
  return "WARN"
}

# --- Main ---
$config = Read-JsonFile -Path $ConfigPath
if ($null -eq $config.servers -or $config.servers.Count -lt 1) { throw "config.json: servers[] is empty" }
if ($null -eq $config.auth)    { $config | Add-Member -NotePropertyName auth    -NotePropertyValue @{ mode="Windows" } -Force }
if ($null -eq $config.output)  { $config | Add-Member -NotePropertyName output  -NotePropertyValue @{ folder="." } -Force }
if ($null -eq $config.options) { $config | Add-Member -NotePropertyName options -NotePropertyValue @{ commandTimeoutSeconds=60 } -Force }

$baseline = Read-Baseline -Path $BaselinePath

$outFolder = $config.output.folder
Ensure-Folder -Path $outFolder

$outPath = Join-Path $outFolder $OutputFileName
$highRiskPath = Join-Path $outFolder $HighRiskFileName

$timeout = 60
if ($config.options.PSObject.Properties.Name -contains "commandTimeoutSeconds" -and $config.options.commandTimeoutSeconds) {
  $timeout = [int]$config.options.commandTimeoutSeconds
}

$results = New-Object System.Collections.Generic.List[object]
$ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

foreach ($srv in $config.servers) {
  $alias = $null
  if ($srv.PSObject.Properties.Name -contains "alias") { $alias = [string]$srv.alias }
  if ([string]::IsNullOrWhiteSpace($alias)) { $alias = [string]$srv.name }

  $row = [ordered]@{
    Timestamp = $ts
    Server = [string]$srv.name
    Alias = $alias
    ConnectOk = $false
    ProductMajorVersion = $null
    ProductVersion = $null
    ProductLevel = $null
    ProductUpdateLevel = $null
    ProductUpdateReference = $null
    Edition = $null
    RecommendedBuild = $null
    RecommendedLabel = $null
    RecommendedReleased = $null
    ComplianceStatus = "Unknown"

    # --- Enhancements ---
    VersionDelta = $null
    Action = $null
    RiskScore = "WARN"

    Notes = $null
  }

  try {
    $cs = New-ConnString -Server $srv -Auth $config.auth
    $info = Get-SqlInstanceInfo -ConnectionString $cs -TimeoutSeconds $timeout

    if ($null -eq $info) {
      $row.Notes = "No data returned"
      $results.Add([pscustomobject]$row) | Out-Null
      continue
    }

    $row.ConnectOk = $true
    $row.ProductMajorVersion = [int]$info.ProductMajorVersion
    $row.ProductVersion = [string]$info.ProductVersion
    $row.ProductLevel = [string]$info.ProductLevel
    $row.ProductUpdateLevel = [string]$info.ProductUpdateLevel
    $row.ProductUpdateReference = [string]$info.ProductUpdateReference
    $row.Edition = [string]$info.Edition

    $majorKey = [string]$row.ProductMajorVersion
    if ($baseline.ContainsKey($majorKey)) {
      $row.RecommendedBuild = $baseline[$majorKey].RecommendedBuild
      $row.RecommendedLabel = $baseline[$majorKey].RecommendedLabel
      $row.RecommendedReleased = $baseline[$majorKey].Released

      $cmp = Compare-Build -CurrentBuild $row.ProductVersion -RecommendedBuild $row.RecommendedBuild
      $row.ComplianceStatus = $cmp.Status

      # VersionDelta + Action
      if ($cmp.Cur -ne $null -and $cmp.Rec -ne $null) {
        $row.VersionDelta = "{0} -> {1}" -f $cmp.Cur, $cmp.Rec
      } else {
        $row.VersionDelta = "{0} -> {1}" -f $row.ProductVersion, $row.RecommendedBuild
      }

      if ($row.ComplianceStatus -eq "Outdated") {
        $row.Action = "Install update to reach baseline: {0} ({1})" -f $row.RecommendedBuild, $row.RecommendedLabel
      } elseif ($row.ComplianceStatus -eq "UpToDate") {
        $row.Action = "OK"
      } else {
        $row.Action = "Review (unknown compliance)"
      }

      # RiskScore
      $row.RiskScore = Get-RiskScore -ProductUpdateLevel $row.ProductUpdateLevel -ComplianceStatus $row.ComplianceStatus

      # Extra hint for RTM -> plan maintenance window
      if (($row.ProductUpdateLevel ?? "").Trim().ToUpperInvariant() -eq "RTM" -and $row.ComplianceStatus -eq "Outdated") {
        $row.Notes = "RTM detected; large jump to baseline. Plan maintenance window + service restart."
      }
    }
    else {
      $row.Notes = "No baseline for major version: $majorKey"
      $row.RiskScore = "WARN"
      $row.Action = "Add baseline for this major version"
    }
  }
  catch {
    $row.ConnectOk = $false
    $row.ComplianceStatus = "Unknown"
    $row.RiskScore = "CRIT"
    $row.Action = "Fix connectivity / auth"
    $row.Notes = $_.Exception.Message
  }

  $results.Add([pscustomobject]$row) | Out-Null
}

# Export full report
$results | Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8

# Export high-risk report (WARN/CRIT)
$highRisk = $results | Where-Object { $_.RiskScore -in @("WARN","CRIT") -or $_.ComplianceStatus -in @("Outdated","Unknown") }
$highRisk | Export-Csv -LiteralPath $highRiskPath -NoTypeInformation -Encoding UTF8

Write-Host "Patch compliance report saved to: $outPath"
Write-Host "High-risk patch compliance report saved to: $highRiskPath"