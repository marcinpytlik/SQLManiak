#requires -Version 5.1
<#
.SYNOPSIS
  Security compare v2 (hardened): DB users + DB role memberships + server logins + server roles.
  Generates FIX.sql to remediate missing logins/users/roles and orphaned users.

.DESCRIPTION
  Reads config.json containing:
    - source, destination
    - connectionOptions (encrypt/trustServerCertificate/connectionTimeoutSec/hostNameInCertificate)
    - sourceCredential / destinationCredential (optional, type=sql + credentialPath to .clixml)
    - databases (optional)
    - logOptions (optional): logDir, alsoWriteToConsole

  Outputs in logDir:
    - security_run_YYYYMMDD_HHMMSS.log
    - security_diff_YYYYMMDD_HHMMSS.log
    - FIX_YYYYMMDD_HHMMSS.sql
    - snapshot_serverlogins_source/destination.csv
    - snapshot_serverroles_source/destination.csv
    - snapshot_dbusers_source/destination.csv
    - snapshot_dbroles_source/destination.csv

WHAT'S NEW (hardened):
  - Robust Write-Log (no crash on empty message)
  - Centralized error details logging
  - Try/Catch around ALL major phases + per-DB snapshot
  - Invoke-Sqlcmd wrapper with better diagnostics
  - Robust Export-Csv (force string paths + arrays) + per-export try/catch
  - DBNull/empty-string safe int conversion

.NOTES
  - For SQL logins we cannot recover original password -> FIX.sql uses a placeholder password.
    You must replace it.
  - For contained database users (authentication_type_desc = DATABASE) we cannot recreate password.
    FIX.sql emits a comment for manual action.
#>

param(
  [Parameter(Mandatory)]
  [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

# -------------------- Utilities --------------------

function Import-RequiredModules {
  if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    throw "Brak modułu SqlServer. Zainstaluj offline lub dołóż moduł."
  }
  Import-Module SqlServer -ErrorAction Stop
}

function Ensure-Dir([Parameter(Mandatory)][string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Write-Log {
  param(
    [Parameter(Mandatory)][string]$LogFile,
    [AllowNull()][AllowEmptyString()][string]$Message,
    [switch]$ToConsole
  )

  # Never crash on empty message
  if ([string]::IsNullOrWhiteSpace($Message)) { $Message = "<EMPTY_MESSAGE>" }

  $line = "{0} | {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $Message
  try {
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
  } catch {
    # last resort - avoid killing the run if filesystem is flaky
    Write-Host "LOG_WRITE_FAILED: $line"
    Write-Host $_.Exception.Message
  }
  if ($ToConsole) { Write-Host $line }
}

function Get-ErrorDetails {
  param([Parameter(Mandatory)]$Err)

  $inv = $Err.InvocationInfo
  $ex  = $Err.Exception

  $lineText = $null; $lineNo = $null; $script = $null
  if ($null -ne $inv) { $lineText = $inv.Line; $lineNo = $inv.ScriptLineNumber; $script = $inv.ScriptName }

  $stack = $null
  if ($null -ne $ex -and $ex.StackTrace) {
    $stack = ($ex.StackTrace -split "`r?`n" | Select-Object -First 12) -join " | "
  }

  [pscustomobject]@{
    Message = if ($null -ne $ex) { $ex.Message } else { $Err.ToString() }
    Type    = if ($null -ne $ex) { $ex.GetType().FullName } else { $null }
    Script  = $script
    LineNo  = $lineNo
    Line    = $lineText
    Stack   = $stack
  }
}

function Safe-LogError {
  param(
    [Parameter(Mandatory)][string]$LogFile,
    [Parameter(Mandatory)][string]$Prefix,
    [Parameter(Mandatory)]$Err,
    [switch]$ToConsole
  )
  $e = Get-ErrorDetails $Err
  Write-Log -LogFile $LogFile -Message ("ERROR | {0} | {1}" -f $Prefix,$e.Message) -ToConsole:$ToConsole
  if ($e.Type)   { Write-Log -LogFile $LogFile -Message ("ERROR | {0} | TYPE  | {1}" -f $Prefix,$e.Type) -ToConsole:$ToConsole }
  if ($e.Script -and $e.LineNo) { Write-Log -LogFile $LogFile -Message ("ERROR | {0} | AT    | {1}:{2}" -f $Prefix,$e.Script,$e.LineNo) -ToConsole:$ToConsole }
  if ($e.Line)   { Write-Log -LogFile $LogFile -Message ("ERROR | {0} | LINE  | {1}" -f $Prefix,$e.Line) -ToConsole:$ToConsole }
  if ($e.Stack)  { Write-Log -LogFile $LogFile -Message ("ERROR | {0} | STACK | {1}" -f $Prefix,$e.Stack) -ToConsole:$ToConsole }
}

function Invoke-Sql {
  param(
    [Parameter(Mandatory)]$Conn,
    [Parameter(Mandatory)][string]$Database,
    [Parameter(Mandatory)][string]$Query,
    [Parameter(Mandatory)][string]$ContextLog,
    [Parameter(Mandatory)][string]$ContextTag,
    [switch]$ToConsole
  )
  try {
    return @(Invoke-Sqlcmd @Conn -Database $Database -Query $Query)
  } catch {
    Safe-LogError -LogFile $ContextLog -Prefix ("Invoke-Sql [{0}] db={1}" -f $ContextTag,$Database) -Err $_ -ToConsole:$ToConsole
    throw
  }
}

function New-ConnParams {
  param(
    [Parameter(Mandatory)][string]$ServerInstance,
    $CredCfg,
    $ConnOptions
  )

  $p = @{
    ServerInstance          = $ServerInstance
    QueryTimeout            = 0
    ConnectionTimeout       = 30
    ErrorAction             = "Stop"
    Encrypt                 = "Optional"
    TrustServerCertificate  = $true
  }

  if ($null -ne $ConnOptions) {
    if ($ConnOptions.PSObject.Properties.Name -contains 'encrypt' -and $ConnOptions.encrypt) {
      $p.Encrypt = [string]$ConnOptions.encrypt
    }
    if ($ConnOptions.PSObject.Properties.Name -contains 'trustServerCertificate' -and $null -ne $ConnOptions.trustServerCertificate) {
      $p.TrustServerCertificate = [bool]$ConnOptions.trustServerCertificate
    }
    if ($ConnOptions.PSObject.Properties.Name -contains 'connectionTimeoutSec' -and $ConnOptions.connectionTimeoutSec) {
      $p.ConnectionTimeout = [int]$ConnOptions.connectionTimeoutSec
    }
    if ($ConnOptions.PSObject.Properties.Name -contains 'hostNameInCertificate' -and $ConnOptions.hostNameInCertificate) {
      $p.HostNameInCertificate = [string]$ConnOptions.hostNameInCertificate
    }
  }

  if ($null -ne $CredCfg -and $CredCfg.type -and $CredCfg.type.ToLower() -eq "sql") {
    if (-not $CredCfg.credentialPath) { throw "credential type=sql wymaga credentialPath do .clixml (Export-Clixml)." }
    $p.Credential = Import-Clixml -Path $CredCfg.credentialPath
  }

  return $p
}

function Get-DatabaseList {
  param($Cfg, $Conn, [string]$RunLog, [switch]$ToConsole)

  if ($Cfg.PSObject.Properties.Name -contains 'databases' -and $null -ne $Cfg.databases -and @($Cfg.databases).Count -gt 0) {
    return @($Cfg.databases | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ })
  }

  $q = @"
SELECT name
FROM sys.databases
WHERE database_id > 4
  AND state_desc='ONLINE';
"@
  return @((Invoke-Sql -Conn $Conn -Database "master" -Query $q -ContextLog $RunLog -ContextTag "Get-DatabaseList" -ToConsole:$ToConsole).name)
}

function SqlIdent([string]$Name) {
  if ($null -eq $Name) { return "[]" }
  return "[" + ($Name -replace "]", "]]") + "]"
}

function BytesToHex {
  param($Value)
  if ($null -eq $Value) { return $null }
  if ($Value -is [System.DBNull]) { return $null }

  if ($Value -is [byte[]]) { return "0x" + (($Value | ForEach-Object { $_.ToString("X2") }) -join "") }
  $s = $Value.ToString()
  if ($s.StartsWith("0x")) { return $s }

  $b = [System.Text.Encoding]::Unicode.GetBytes($s)
  return "0x" + (($b | ForEach-Object { $_.ToString("X2") }) -join "")
}

function To-NullableInt {
  param($Value)
  if ($null -eq $Value) { return $null }
  if ($Value -is [System.DBNull]) { return $null }

  $s = $Value.ToString().Trim()
  if ($s -eq "") { return $null }
  if ($s -match '^(true|false)$') { return [int]([bool]::Parse($s)) }
  try { return [int]$s } catch { return $null }
}

# -------------------- Snapshot Queries --------------------

function Get-ServerLoginsSnapshot {
  param($Conn, [ValidateSet("Source","Destination")][string]$Side, [string]$RunLog, [switch]$ToConsole)

  $q = @"
SELECT
  @@SERVERNAME AS ServerName,
  sp.name AS LoginName,
  sp.type_desc AS LoginType,
  sp.is_disabled AS IsDisabled,
  sp.default_database_name AS DefaultDatabase,
  sp.default_language_name AS DefaultLanguage,
  sp.sid AS Sid,
  sl.is_policy_checked AS IsPolicyChecked,
  sl.is_expiration_checked AS IsExpirationChecked
FROM sys.server_principals sp
LEFT JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
WHERE sp.type IN ('S','U','G')
  AND sp.name NOT LIKE '##%'
ORDER BY sp.type_desc, sp.name;
"@

  @(Invoke-Sql -Conn $Conn -Database "master" -Query $q -ContextLog $RunLog -ContextTag "Get-ServerLoginsSnapshot:$Side" -ToConsole:$ToConsole) | ForEach-Object {
    [pscustomobject]@{
      Side                = $Side
      ServerName          = $_.ServerName
      LoginName           = $_.LoginName
      LoginType           = $_.LoginType
      IsDisabled          = (To-NullableInt $_.IsDisabled)
      DefaultDatabase     = $_.DefaultDatabase
      DefaultLanguage     = $_.DefaultLanguage
      SidHex              = (BytesToHex $_.Sid)
      IsPolicyChecked     = (To-NullableInt $_.IsPolicyChecked)
      IsExpirationChecked = (To-NullableInt $_.IsExpirationChecked)
    }
  }
}

function Get-ServerRoleMembersSnapshot {
  param($Conn, [ValidateSet("Source","Destination")][string]$Side, [string]$RunLog, [switch]$ToConsole)

  $q = @"
SELECT
  @@SERVERNAME AS ServerName,
  r.name AS RoleName,
  m.name AS MemberName,
  m.type_desc AS MemberType
FROM sys.server_role_members rm
JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
ORDER BY r.name, m.name;
"@
  @(Invoke-Sql -Conn $Conn -Database "master" -Query $q -ContextLog $RunLog -ContextTag "Get-ServerRoleMembersSnapshot:$Side" -ToConsole:$ToConsole) | ForEach-Object {
    [pscustomobject]@{
      Side       = $Side
      ServerName = $_.ServerName
      RoleName   = $_.RoleName
      MemberName = $_.MemberName
      MemberType = $_.MemberType
    }
  }
}

function Get-DbUsersSnapshot {
  param($Conn, [string]$DbName, [ValidateSet("Source","Destination")][string]$Side, [string]$RunLog, [switch]$ToConsole)

  $q = @"
SELECT
  @@SERVERNAME AS ServerName,
  DB_NAME() AS DatabaseName,
  dp.name AS DbUserName,
  dp.type_desc AS DbPrincipalType,
  dp.authentication_type_desc AS AuthenticationType,
  dp.default_schema_name AS DefaultSchema,
  dp.sid AS DbSid,
  sp.name AS MappedServerLogin,
  sp.type_desc AS MappedServerLoginType
FROM sys.database_principals dp
LEFT JOIN sys.server_principals sp ON dp.sid = sp.sid
WHERE dp.type IN ('S','U','G','E','X')
  AND dp.name NOT IN ('dbo','guest','INFORMATION_SCHEMA','sys')
ORDER BY dp.type_desc, dp.name;
"@

  @(Invoke-Sql -Conn $Conn -Database $DbName -Query $q -ContextLog $RunLog -ContextTag "Get-DbUsersSnapshot:$Side:$DbName" -ToConsole:$ToConsole) | ForEach-Object {
    $isContained = ($_.AuthenticationType -eq "DATABASE")
    $mapped = $_.MappedServerLogin
    $isOrphanCandidate = 0
    if (-not $isContained) { if ([string]::IsNullOrWhiteSpace($mapped)) { $isOrphanCandidate = 1 } }

    [pscustomobject]@{
      Side               = $Side
      ServerName         = $_.ServerName
      DatabaseName       = $_.DatabaseName
      DbUserName         = $_.DbUserName
      DbPrincipalType    = $_.DbPrincipalType
      AuthenticationType = $_.AuthenticationType
      DefaultSchema      = $_.DefaultSchema
      DbSidHex           = (BytesToHex $_.DbSid)
      MappedServerLogin  = $mapped
      MappedLoginType    = $_.MappedServerLoginType
      IsContained        = (To-NullableInt $isContained)
      IsOrphanCandidate  = (To-NullableInt $isOrphanCandidate)
    }
  }
}

function Get-DbRoleMembersSnapshot {
  param($Conn, [string]$DbName, [ValidateSet("Source","Destination")][string]$Side, [string]$RunLog, [switch]$ToConsole)

  $q = @"
SELECT
  @@SERVERNAME AS ServerName,
  DB_NAME() AS DatabaseName,
  r.name AS RoleName,
  m.name AS MemberName,
  m.type_desc AS MemberType
FROM sys.database_role_members rm
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
WHERE r.type='R'
  AND m.name NOT IN ('dbo','guest','INFORMATION_SCHEMA','sys')
ORDER BY r.name, m.name;
"@

  @(Invoke-Sql -Conn $Conn -Database $DbName -Query $q -ContextLog $RunLog -ContextTag "Get-DbRoleMembersSnapshot:$Side:$DbName" -ToConsole:$ToConsole) | ForEach-Object {
    [pscustomobject]@{
      Side         = $Side
      ServerName   = $_.ServerName
      DatabaseName = $_.DatabaseName
      RoleName     = $_.RoleName
      MemberName   = $_.MemberName
      MemberType   = $_.MemberType
    }
  }
}

function IndexByKey {
  param([object[]]$Rows, [scriptblock]$KeySelector)
  $h = @{}
  foreach ($r in $Rows) {
    $k = & $KeySelector $r
    $h[$k] = $r
  }
  return $h
}

function Compare-Set {
  param([string[]]$SourceKeys,[string[]]$DestKeys)

  $src = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($k in $SourceKeys) { [void]$src.Add($k) }
  $dst = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($k in $DestKeys) { [void]$dst.Add($k) }

  $all = @($SourceKeys + $DestKeys | Sort-Object -Unique)
  $onlyS = New-Object System.Collections.Generic.List[string]
  $onlyD = New-Object System.Collections.Generic.List[string]

  foreach ($k in $all) {
    $inS = $src.Contains($k)
    $inD = $dst.Contains($k)
    if ($inS -and -not $inD) { $onlyS.Add($k) | Out-Null }
    elseif ($inD -and -not $inS) { $onlyD.Add($k) | Out-Null }
  }

  [pscustomobject]@{ OnlySource=@($onlyS); OnlyDest=@($onlyD) }
}

# -------------------- MAIN --------------------

try {
  Import-RequiredModules

  if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Nie znaleziono pliku config: $ConfigPath" }
  $cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

  $logDir = if ($cfg.PSObject.Properties.Name -contains 'logOptions' -and $cfg.logOptions -and $cfg.logOptions.logDir) {
    [string]$cfg.logOptions.logDir
  } else {
    (Join-Path $scriptDir "logs")
  }
  Ensure-Dir -Path $logDir

  $alsoConsole = $true
  if ($cfg.PSObject.Properties.Name -contains 'logOptions' -and $cfg.logOptions -and $null -ne $cfg.logOptions.alsoWriteToConsole) {
    $alsoConsole = [bool]$cfg.logOptions.alsoWriteToConsole
  }

  $runTs  = Get-Date -Format "yyyyMMdd_HHmmss"
  $runLog = Join-Path $logDir ("security_run_{0}.log" -f $runTs)
  $diffLog= Join-Path $logDir ("security_diff_{0}.log" -f $runTs)
  $fixSql = Join-Path $logDir ("FIX_{0}.sql" -f $runTs)

  Write-Log -LogFile $runLog -Message ("START | source={0} destination={1}" -f $cfg.source,$cfg.destination) -ToConsole:($alsoConsole)

  $sourceConn = New-ConnParams -ServerInstance $cfg.source -CredCfg $cfg.sourceCredential -ConnOptions $cfg.connectionOptions
  $destConn   = New-ConnParams -ServerInstance $cfg.destination -CredCfg $cfg.destinationCredential -ConnOptions $cfg.connectionOptions

  # Connectivity
  Invoke-Sql -Conn $sourceConn -Database "master" -Query "SELECT 'SRC_OK' AS ok, @@SERVERNAME AS srv;" -ContextLog $runLog -ContextTag "Connectivity:Source" -ToConsole:$alsoConsole | Out-Null
  Invoke-Sql -Conn $destConn   -Database "master" -Query "SELECT 'DST_OK' AS ok, @@SERVERNAME AS srv;" -ContextLog $runLog -ContextTag "Connectivity:Dest"   -ToConsole:$alsoConsole | Out-Null
  Write-Log -LogFile $runLog -Message "INFO  | connectivity OK" -ToConsole:($alsoConsole)

  # Databases
  $dbs = @(Get-DatabaseList -Cfg $cfg -Conn $sourceConn -RunLog $runLog -ToConsole:$alsoConsole)
  if (@($dbs).Count -eq 0) { throw "Brak baz do porównania." }
  Write-Log -LogFile $runLog -Message ("INFO  | db_count={0}" -f @($dbs).Count) -ToConsole:($alsoConsole)

  # Snapshots: server level
  Write-Log -LogFile $runLog -Message "INFO  | collecting server logins + server roles..." -ToConsole:($alsoConsole)
  $srcLogins   = @(Get-ServerLoginsSnapshot -Conn $sourceConn -Side Source      -RunLog $runLog -ToConsole:$alsoConsole)
  $dstLogins   = @(Get-ServerLoginsSnapshot -Conn $destConn   -Side Destination -RunLog $runLog -ToConsole:$alsoConsole)
  $srcSrvRoles = @(Get-ServerRoleMembersSnapshot -Conn $sourceConn -Side Source      -RunLog $runLog -ToConsole:$alsoConsole)
  $dstSrvRoles = @(Get-ServerRoleMembersSnapshot -Conn $destConn   -Side Destination -RunLog $runLog -ToConsole:$alsoConsole)

  # Snapshots: db level
  $srcDbUsers = New-Object System.Collections.Generic.List[object]
  $dstDbUsers = New-Object System.Collections.Generic.List[object]
  $srcDbRoles = New-Object System.Collections.Generic.List[object]
  $dstDbRoles = New-Object System.Collections.Generic.List[object]

  foreach ($db in $dbs) {
    try {
      Write-Log -LogFile $runLog -Message ("INFO  | collecting DB snapshot | {0}" -f $db) -ToConsole:($alsoConsole)

      foreach ($u in @(Get-DbUsersSnapshot -Conn $sourceConn -DbName $db -Side Source      -RunLog $runLog -ToConsole:$alsoConsole)) { $srcDbUsers.Add($u) | Out-Null }
      foreach ($u in @(Get-DbUsersSnapshot -Conn $destConn   -DbName $db -Side Destination -RunLog $runLog -ToConsole:$alsoConsole)) { $dstDbUsers.Add($u) | Out-Null }

      foreach ($r in @(Get-DbRoleMembersSnapshot -Conn $sourceConn -DbName $db -Side Source      -RunLog $runLog -ToConsole:$alsoConsole)) { $srcDbRoles.Add($r) | Out-Null }
      foreach ($r in @(Get-DbRoleMembersSnapshot -Conn $destConn   -DbName $db -Side Destination -RunLog $runLog -ToConsole:$alsoConsole)) { $dstDbRoles.Add($r) | Out-Null }
    } catch {
      Safe-LogError -LogFile $runLog -Prefix ("DB_SNAPSHOT db={0}" -f $db) -Err $_ -ToConsole:$alsoConsole
      # continue next DB
      continue
    }
  }

  # Export snapshots to CSV (robust)
  try {
    Write-Log -LogFile $runLog -Message "INFO  | exporting snapshots to CSV..." -ToConsole:($alsoConsole)

    $logDirS = [string]$logDir
    $csvSrcLogins    = Join-Path $logDirS ("snapshot_serverlogins_source_{0}.csv" -f $runTs)
    $csvDstLogins    = Join-Path $logDirS ("snapshot_serverlogins_destination_{0}.csv" -f $runTs)
    $csvSrcSrvRoles  = Join-Path $logDirS ("snapshot_serverroles_source_{0}.csv" -f $runTs)
    $csvDstSrvRoles  = Join-Path $logDirS ("snapshot_serverroles_destination_{0}.csv" -f $runTs)
    $csvSrcDbUsers   = Join-Path $logDirS ("snapshot_dbusers_source_{0}.csv" -f $runTs)
    $csvDstDbUsers   = Join-Path $logDirS ("snapshot_dbusers_destination_{0}.csv" -f $runTs)
    $csvSrcDbRoles   = Join-Path $logDirS ("snapshot_dbroles_source_{0}.csv" -f $runTs)
    $csvDstDbRoles   = Join-Path $logDirS ("snapshot_dbroles_destination_{0}.csv" -f $runTs)

    @($srcLogins)   | Export-Csv -LiteralPath ([string]$csvSrcLogins)   -NoTypeInformation -Encoding UTF8
    @($dstLogins)   | Export-Csv -LiteralPath ([string]$csvDstLogins)   -NoTypeInformation -Encoding UTF8
    @($srcSrvRoles) | Export-Csv -LiteralPath ([string]$csvSrcSrvRoles) -NoTypeInformation -Encoding UTF8
    @($dstSrvRoles) | Export-Csv -LiteralPath ([string]$csvDstSrvRoles) -NoTypeInformation -Encoding UTF8
    $srcDbUsers.ToArray() | Export-Csv -LiteralPath ([string]$csvSrcDbUsers) -NoTypeInformation -Encoding UTF8
    $dstDbUsers.ToArray() | Export-Csv -LiteralPath ([string]$csvDstDbUsers) -NoTypeInformation -Encoding UTF8
    $srcDbRoles.ToArray() | Export-Csv -LiteralPath ([string]$csvSrcDbRoles) -NoTypeInformation -Encoding UTF8
    $dstDbRoles.ToArray() | Export-Csv -LiteralPath ([string]$csvDstDbRoles) -NoTypeInformation -Encoding UTF8

    Write-Log -LogFile $runLog -Message "INFO  | exporting snapshots to CSV OK" -ToConsole:($alsoConsole)
  } catch {
    Safe-LogError -LogFile $runLog -Prefix "EXPORT_CSV" -Err $_ -ToConsole:$alsoConsole
    # continue; we still want FIX.sql and diff
  }

  # -------------------- COMPARE + FIX GENERATION --------------------

  $fixLines = New-Object System.Collections.Generic.List[string]
  $fixLines.Add("/*") | Out-Null
  $fixLines.Add("  FIX script generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
  $fixLines.Add("  Source:      $($cfg.source)") | Out-Null
  $fixLines.Add("  Destination: $($cfg.destination)") | Out-Null
  $fixLines.Add("  NOTE: Review before running in prod.") | Out-Null
  $fixLines.Add("*/") | Out-Null
  $fixLines.Add("") | Out-Null
  $fixLines.Add("SET NOCOUNT ON;") | Out-Null
  $fixLines.Add("") | Out-Null

  $srcLoginByName = IndexByKey -Rows $srcLogins -KeySelector { param($x) $x.LoginName.ToLowerInvariant() }

  # Map SOURCE db user -> mapped login (per db)
  $srcDbUserToLogin = @{}
  foreach ($u in $srcDbUsers.ToArray()) {
    $key = "{0}|{1}|{2}|{3}" -f $u.DatabaseName.ToLowerInvariant(), $u.DbUserName.ToLowerInvariant(), $u.DbPrincipalType, $u.AuthenticationType
    if (-not [string]::IsNullOrWhiteSpace($u.MappedServerLogin)) { $srcDbUserToLogin[$key] = $u.MappedServerLogin }
  }

  # 1) Missing logins on destination
  Write-Log -LogFile $diffLog -Message "==== SERVER LOGINS ====" -ToConsole:($alsoConsole)

  $srcLoginKeys = @($srcLogins | ForEach-Object { $_.LoginName.ToLowerInvariant() })
  $dstLoginKeys = @($dstLogins | ForEach-Object { $_.LoginName.ToLowerInvariant() })
  $loginDiff = Compare-Set -SourceKeys $srcLoginKeys -DestKeys $dstLoginKeys

  if (@($loginDiff.OnlySource).Count -eq 0) {
    Write-Log -LogFile $diffLog -Message "LOGINS | OK | no missing logins on destination" -ToConsole:($alsoConsole)
  } else {
    Write-Log -LogFile $diffLog -Message ("LOGINS | MISSING_ON_DEST | count={0}" -f @($loginDiff.OnlySource).Count) -ToConsole:($alsoConsole)

    $fixLines.Add("/* ===== 1) CREATE MISSING LOGINS ON DESTINATION ===== */") | Out-Null
    $fixLines.Add("USE [master];") | Out-Null
    $fixLines.Add("GO") | Out-Null

    foreach ($k in $loginDiff.OnlySource) {
      $s = $srcLoginByName[$k]
      if ($null -eq $s) { continue }

      $loginName = $s.LoginName
      $loginType = $s.LoginType

      Write-Log -LogFile $diffLog -Message ("LOGINS | ONLY_ON_SOURCE | {0} | type={1}" -f $loginName,$loginType) -ToConsole:($alsoConsole)

      if ($loginType -eq "SQL_LOGIN") {
        $sid = $s.SidHex
        $pol = if ($s.IsPolicyChecked -eq 1) { "ON" } else { "OFF" }
        $exp = if ($s.IsExpirationChecked -eq 1) { "ON" } else { "OFF" }
        $defDb = if ($s.DefaultDatabase) { ", DEFAULT_DATABASE = $(SqlIdent $s.DefaultDatabase)" } else { "" }
        $defLang = if ($s.DefaultLanguage) { ", DEFAULT_LANGUAGE = $(SqlIdent $s.DefaultLanguage)" } else { "" }

        $fixLines.Add("-- SQL_LOGIN missing: $loginName") | Out-Null
        $fixLines.Add("IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$loginName')") | Out-Null
        $fixLines.Add("BEGIN") | Out-Null
        $fixLines.Add("  CREATE LOGIN $(SqlIdent $loginName) WITH PASSWORD = N'__CHANGE_ME_STRONG_PASSWORD__', SID = $sid, CHECK_POLICY = $pol, CHECK_EXPIRATION = $exp$defDb$defLang;") | Out-Null
        $fixLines.Add("END") | Out-Null
        $fixLines.Add("GO") | Out-Null

        if ($s.IsDisabled -eq 1) {
          $fixLines.Add("ALTER LOGIN $(SqlIdent $loginName) DISABLE;") | Out-Null
          $fixLines.Add("GO") | Out-Null
        }
      }
      elseif ($loginType -eq "WINDOWS_LOGIN" -or $loginType -eq "WINDOWS_GROUP") {
        $fixLines.Add("-- WINDOWS principal missing: $loginName") | Out-Null
        $fixLines.Add("IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$loginName')") | Out-Null
        $fixLines.Add("BEGIN") | Out-Null
        $fixLines.Add("  CREATE LOGIN $(SqlIdent $loginName) FROM WINDOWS;") | Out-Null
        $fixLines.Add("END") | Out-Null
        $fixLines.Add("GO") | Out-Null

        if ($s.IsDisabled -eq 1) {
          $fixLines.Add("ALTER LOGIN $(SqlIdent $loginName) DISABLE;") | Out-Null
          $fixLines.Add("GO") | Out-Null
        }
      }
      else {
        $fixLines.Add("-- SKIP unsupported login type: $loginType for $loginName") | Out-Null
      }
    }
  }

  # 2) Server role memberships missing on dest
  Write-Log -LogFile $diffLog -Message "" -ToConsole:($alsoConsole)
  Write-Log -LogFile $diffLog -Message "==== SERVER ROLES ====" -ToConsole:($alsoConsole)

  $srcSrvRoleKeys = @($srcSrvRoles | ForEach-Object { "{0}|{1}" -f $_.RoleName.ToLowerInvariant(), $_.MemberName.ToLowerInvariant() })
  $dstSrvRoleKeys = @($dstSrvRoles | ForEach-Object { "{0}|{1}" -f $_.RoleName.ToLowerInvariant(), $_.MemberName.ToLowerInvariant() })
  $srvRoleDiff = Compare-Set -SourceKeys $srcSrvRoleKeys -DestKeys $dstSrvRoleKeys

  if (@($srvRoleDiff.OnlySource).Count -eq 0) {
    Write-Log -LogFile $diffLog -Message "SERVER_ROLES | OK | no missing memberships on destination" -ToConsole:($alsoConsole)
  } else {
    Write-Log -LogFile $diffLog -Message ("SERVER_ROLES | MISSING_ON_DEST | count={0}" -f @($srvRoleDiff.OnlySource).Count) -ToConsole:($alsoConsole)

    $fixLines.Add("") | Out-Null
    $fixLines.Add("/* ===== 2) ADD MISSING SERVER ROLE MEMBERSHIPS ON DESTINATION ===== */") | Out-Null
    $fixLines.Add("USE [master];") | Out-Null
    $fixLines.Add("GO") | Out-Null

    foreach ($k in $srvRoleDiff.OnlySource) {
      $parts = $k.Split('|',2)
      $role = $parts[0]
      $member = $parts[1]

      Write-Log -LogFile $diffLog -Message ("SERVER_ROLES | ONLY_ON_SOURCE | role={0} member={1}" -f $role,$member) -ToConsole:($alsoConsole)

      $fixLines.Add("IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$member')") | Out-Null
      $fixLines.Add("BEGIN") | Out-Null
      $fixLines.Add("  ALTER SERVER ROLE $(SqlIdent $role) ADD MEMBER $(SqlIdent $member);") | Out-Null
      $fixLines.Add("END") | Out-Null
      $fixLines.Add("GO") | Out-Null
    }
  }

  # 3) Per DB users + roles
  $fixLines.Add("") | Out-Null
  $fixLines.Add("/* ===== 3) DATABASE USERS + ROLE MEMBERSHIPS ===== */") | Out-Null

  foreach ($db in $dbs) {
    Write-Log -LogFile $diffLog -Message "" -ToConsole:($alsoConsole)
    Write-Log -LogFile $diffLog -Message ("==== DB: {0} ====" -f $db) -ToConsole:($alsoConsole)

    $srcUsersDb = @($srcDbUsers.ToArray() | Where-Object { $_.DatabaseName -eq $db })
    $dstUsersDb = @($dstDbUsers.ToArray() | Where-Object { $_.DatabaseName -eq $db })
    $srcRolesDb = @($srcDbRoles.ToArray() | Where-Object { $_.DatabaseName -eq $db })
    $dstRolesDb = @($dstDbRoles.ToArray() | Where-Object { $_.DatabaseName -eq $db })

    $srcUserKeys = @($srcUsersDb | ForEach-Object { "{0}|{1}|{2}" -f $_.DbUserName.ToLowerInvariant(), $_.DbPrincipalType, $_.AuthenticationType })
    $dstUserKeys = @($dstUsersDb | ForEach-Object { "{0}|{1}|{2}" -f $_.DbUserName.ToLowerInvariant(), $_.DbPrincipalType, $_.AuthenticationType })
    $uDiff = Compare-Set -SourceKeys $srcUserKeys -DestKeys $dstUserKeys

    $fixLines.Add("") | Out-Null
    $fixLines.Add("/* ---- DB: $db ---- */") | Out-Null
    $fixLines.Add("USE $(SqlIdent $db);") | Out-Null
    $fixLines.Add("GO") | Out-Null

    if (@($uDiff.OnlySource).Count -gt 0) {
      Write-Log -LogFile $diffLog -Message ("DB_USERS | MISSING_ON_DEST | count={0}" -f @($uDiff.OnlySource).Count) -ToConsole:($alsoConsole)

      foreach ($k in $uDiff.OnlySource) {
        $parts = $k.Split('|',3)
        $userLower = $parts[0]
        $typeDesc  = $parts[1]
        $authType  = $parts[2]

        $srcUser = $srcUsersDb | Where-Object { $_.DbUserName.ToLowerInvariant() -eq $userLower -and $_.DbPrincipalType -eq $typeDesc -and $_.AuthenticationType -eq $authType } | Select-Object -First 1
        if ($null -eq $srcUser) { continue }

        $userName = $srcUser.DbUserName
        Write-Log -LogFile $diffLog -Message ("DB_USERS | ONLY_ON_SOURCE | user={0} type={1} auth={2}" -f $userName,$typeDesc,$authType) -ToConsole:($alsoConsole)

        if ($srcUser.IsContained -eq 1) {
          $fixLines.Add("-- CONTAINED USER on source (cannot auto-create password): $userName") | Out-Null
          $fixLines.Add("-- Manual action required: CREATE USER ... WITH PASSWORD = ...") | Out-Null
          $fixLines.Add("GO") | Out-Null
          continue
        }

        $mapKey = "{0}|{1}|{2}|{3}" -f $db.ToLowerInvariant(), $userName.ToLowerInvariant(), $typeDesc, $authType
        $loginName = $null
        if ($srcDbUserToLogin.ContainsKey($mapKey)) { $loginName = $srcDbUserToLogin[$mapKey] }
        elseif (-not [string]::IsNullOrWhiteSpace($srcUser.MappedServerLogin)) { $loginName = $srcUser.MappedServerLogin }
        else { $loginName = $userName }

        $schema = $srcUser.DefaultSchema
        $schemaClause = if ([string]::IsNullOrWhiteSpace($schema)) { "" } else { " WITH DEFAULT_SCHEMA = $(SqlIdent $schema)" }

        $fixLines.Add("-- Create missing user: $userName") | Out-Null
        $fixLines.Add("IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$userName')") | Out-Null
        $fixLines.Add("BEGIN") | Out-Null
        $fixLines.Add("  IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$loginName')") | Out-Null
        $fixLines.Add("  BEGIN") | Out-Null
        $fixLines.Add("    CREATE USER $(SqlIdent $userName) FOR LOGIN $(SqlIdent $loginName)$schemaClause;") | Out-Null
        $fixLines.Add("  END") | Out-Null
        $fixLines.Add("  ELSE") | Out-Null
        $fixLines.Add("  BEGIN") | Out-Null
        $fixLines.Add("    -- Login missing on destination, create login first (see section 1).") | Out-Null
        $fixLines.Add("  END") | Out-Null
        $fixLines.Add("END") | Out-Null
        $fixLines.Add("GO") | Out-Null
      }
    } else {
      Write-Log -LogFile $diffLog -Message "DB_USERS | OK | no missing users on destination" -ToConsole:($alsoConsole)
    }

    $orphD = @($dstUsersDb | Where-Object { $_.IsOrphanCandidate -eq 1 -and $_.IsContained -eq 0 })
    if (@($orphD).Count -gt 0) {
      Write-Log -LogFile $diffLog -Message ("DB_USERS | ORPHAN_CANDIDATE_ON_DEST | count={0}" -f @($orphD).Count) -ToConsole:($alsoConsole)
      $fixLines.Add("-- Attempt to fix orphan candidates on destination") | Out-Null

      foreach ($u in $orphD) {
        $userName = $u.DbUserName
        $typeDesc = $u.DbPrincipalType
        $authType = $u.AuthenticationType

        $mapKey = "{0}|{1}|{2}|{3}" -f $db.ToLowerInvariant(), $userName.ToLowerInvariant(), $typeDesc, $authType
        $expectedLogin = $null
        if ($srcDbUserToLogin.ContainsKey($mapKey)) { $expectedLogin = $srcDbUserToLogin[$mapKey] }
        else { $expectedLogin = $userName }

        Write-Log -LogFile $diffLog -Message ("DB_USERS | ORPHAN_ON_DEST | user={0} -> expectedLogin={1}" -f $userName,$expectedLogin) -ToConsole:($alsoConsole)

        $fixLines.Add("IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$userName')") | Out-Null
        $fixLines.Add("BEGIN") | Out-Null
        $fixLines.Add("  IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$expectedLogin')") | Out-Null
        $fixLines.Add("  BEGIN") | Out-Null
        $fixLines.Add("    ALTER USER $(SqlIdent $userName) WITH LOGIN = $(SqlIdent $expectedLogin);") | Out-Null
        $fixLines.Add("  END") | Out-Null
        $fixLines.Add("  ELSE") | Out-Null
        $fixLines.Add("  BEGIN") | Out-Null
        $fixLines.Add("    -- Expected login missing on destination. Create login first, then rerun ALTER USER.") | Out-Null
        $fixLines.Add("  END") | Out-Null
        $fixLines.Add("END") | Out-Null
        $fixLines.Add("GO") | Out-Null
      }
    }

    $srcRoleKeys = @($srcRolesDb | ForEach-Object { "{0}|{1}" -f $_.RoleName.ToLowerInvariant(), $_.MemberName.ToLowerInvariant() })
    $dstRoleKeys = @($dstRolesDb | ForEach-Object { "{0}|{1}" -f $_.RoleName.ToLowerInvariant(), $_.MemberName.ToLowerInvariant() })
    $rDiff = Compare-Set -SourceKeys $srcRoleKeys -DestKeys $dstRoleKeys

    if (@($rDiff.OnlySource).Count -eq 0) {
      Write-Log -LogFile $diffLog -Message "DB_ROLES | OK | no missing role memberships on destination" -ToConsole:($alsoConsole)
    } else {
      Write-Log -LogFile $diffLog -Message ("DB_ROLES | MISSING_ON_DEST | count={0}" -f @($rDiff.OnlySource).Count) -ToConsole:($alsoConsole)
      $fixLines.Add("-- Add missing DB role memberships") | Out-Null

      foreach ($k in $rDiff.OnlySource) {
        $parts = $k.Split('|',2)
        $role = $parts[0]
        $member = $parts[1]

        Write-Log -LogFile $diffLog -Message ("DB_ROLES | ONLY_ON_SOURCE | role={0} member={1}" -f $role,$member) -ToConsole:($alsoConsole)

        $fixLines.Add("IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$member')") | Out-Null
        $fixLines.Add("BEGIN") | Out-Null
        $fixLines.Add("  ALTER ROLE $(SqlIdent $role) ADD MEMBER $(SqlIdent $member);") | Out-Null
        $fixLines.Add("END") | Out-Null
        $fixLines.Add("GO") | Out-Null
      }
    }
  }

  # Write FIX.sql
  try {
    Write-Log -LogFile $runLog -Message ("INFO  | writing FIX.sql -> {0}" -f $fixSql) -ToConsole:($alsoConsole)
    $fixLines | Set-Content -LiteralPath $fixSql -Encoding UTF8
  } catch {
    Safe-LogError -LogFile $runLog -Prefix "WRITE_FIX_SQL" -Err $_ -ToConsole:$alsoConsole
    throw
  }

  Write-Log -LogFile $runLog -Message "END | done" -ToConsole:($alsoConsole)

  Write-Host ""
  Write-Host "OK. Run log:  $runLog"
  Write-Host "Diff log: $diffLog"
  Write-Host "FIX.sql:  $fixSql"
} catch {
  # If something escapes, log it somewhere we can
  try {
    $fallback = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) ("security_FATAL_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
    Ensure-Dir -Path (Split-Path -Parent $fallback)
    Safe-LogError -LogFile $fallback -Prefix "FATAL" -Err $_ -ToConsole:$true
    Write-Host "FATAL log: $fallback"
  } catch {
    Write-Host "FATAL (also failed to write log): $($_.Exception.Message)"
  }
  exit 2
}