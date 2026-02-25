<#
.SYNOPSIS
  Postcheck after migration on DESTINATION:
  - Report-only by default
  - Optional apply changes: READ_WRITE, COMPAT 160, Query Store ON + RW + 2GB
  - Always logs orphaned users (no auto-fix)

.USAGE
  # Report-only (safe)
  .\postcheck-migration.ps1 -ConfigPath .\config.json

  # Apply changes
  .\postcheck-migration.ps1 -ConfigPath .\config.json -ApplyChanges
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ConfigPath,

  [switch]$ApplyChanges
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-SqlServerModule {
  if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    throw "Brak modułu 'SqlServer'. Zainstaluj: Install-Module SqlServer -Scope CurrentUser"
  }
  Import-Module SqlServer -ErrorAction Stop
}

function New-LogFile {
  param([string]$LogDir, [string]$Prefix = "postcheck-migration")
  if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
  }
  $ts = Get-Date -Format "yyyyMMdd_HHmmss"
  Join-Path $LogDir "$Prefix`_$ts.log"
}

function Write-Log {
  param(
    [Parameter(Mandatory=$true)][string]$Message,
    [ValidateSet('INFO','WARN','ERROR','OK')][string]$Level = 'INFO',
    [Parameter(Mandatory=$true)][string]$Path,
    [switch]$AlsoConsole
  )
  $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
  Add-Content -LiteralPath $Path -Value $line
  if ($AlsoConsole) { Write-Host $line }
}

function Invoke-Sql {
  param(
    [Parameter(Mandatory=$true)][string]$ServerInstance,
    [Parameter(Mandatory=$true)][string]$Query,
    [string]$Database = "master"
  )
  Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $Query -QueryTimeout 0 -ErrorAction Stop
}

Assert-SqlServerModule

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "Nie znaleziono pliku config: $ConfigPath"
}

$cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

if (-not $cfg.destination) { throw "Config: brak pola 'destination'." }
if (-not $cfg.databases -or $cfg.databases.Count -eq 0) { throw "Config: brak listy 'databases'." }
if (-not $cfg.logOptions.logDir) { throw "Config: brak 'logOptions.logDir'." }

$dest = [string]$cfg.destination
$alsoConsole = ($cfg.logOptions.alsoWriteToConsole -eq $true)
$logFile = New-LogFile -LogDir $cfg.logOptions.logDir

Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "START | Postcheck on DEST=$dest | DBs=$($cfg.databases -join ', ')"
Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "Mode | ApplyChanges=$($ApplyChanges.IsPresent)"

# Queries
function Get-OrphanedUsersQuery([string]$DbName) {
  $dbEsc = $DbName.Replace("'", "''")
  return @"
SET NOCOUNT ON;
USE [$dbEsc];

SELECT
    DB_NAME()            AS DatabaseName,
    dp.name              AS UserName,
    dp.type_desc         AS UserType,
    dp.authentication_type_desc,
    dp.default_schema_name
FROM sys.database_principals dp
LEFT JOIN sys.server_principals sp
    ON dp.sid = sp.sid
WHERE dp.type IN ('S','U','G')                        -- SQL user, Windows user, Windows group
  AND dp.name NOT IN ('dbo','guest','INFORMATION_SCHEMA','sys')
  AND dp.name NOT LIKE '##%##'                        -- system/cert
  AND dp.principal_id > 4
  AND sp.sid IS NULL
ORDER BY dp.type_desc, dp.name;
"@
}

function Get-DbStatusQuery([string]$DbName) {
  $dbEsc = $DbName.Replace("'", "''")
  return @"
SET NOCOUNT ON;

SELECT
  @@SERVERNAME AS ServerName,
  d.name AS DatabaseName,
  d.state_desc,
  d.user_access_desc,
  d.is_read_only,
  d.compatibility_level
FROM sys.databases d
WHERE d.name = N'$dbEsc';
"@
}

function Get-QueryStoreStatusQuery([string]$DbName) {
  $dbEsc = $DbName.Replace("'", "''")
  return @"
SET NOCOUNT ON;
USE [$dbEsc];

SELECT
  actual_state_desc,
  desired_state_desc,
  current_storage_size_mb,
  max_storage_size_mb,
  readonly_reason,
  capture_mode_desc,
  flush_interval_seconds,
  interval_length_minutes,
  stale_query_threshold_days
FROM sys.database_query_store_options;
"@
}

function Get-ApplyChangesQuery([string]$DbName) {
  $dbEsc = $DbName.Replace("'", "''")
  return @"
SET NOCOUNT ON;

DECLARE @db sysname = N'$dbEsc';

IF DB_ID(@db) IS NULL
BEGIN
  THROW 50000, 'Database not found on destination.', 1;
END

DECLARE @sql nvarchar(max) = N'
USE ' + QUOTENAME(@db) + N';

-- 1) Ensure READ_WRITE
ALTER DATABASE ' + QUOTENAME(@db) + N' SET READ_WRITE WITH NO_WAIT;

-- 2) Compatibility Level = 160 (SQL Server 2022)
ALTER DATABASE ' + QUOTENAME(@db) + N' SET COMPATIBILITY_LEVEL = 160;

-- 3) Query Store ON + RW + limit 2GB
ALTER DATABASE ' + QUOTENAME(@db) + N' SET QUERY_STORE = ON;

ALTER DATABASE ' + QUOTENAME(@db) + N' SET QUERY_STORE (
  OPERATION_MODE = READ_WRITE,
  MAX_STORAGE_SIZE_MB = 2048,
  CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
  DATA_FLUSH_INTERVAL_SECONDS = 900,
  INTERVAL_LENGTH_MINUTES = 60,
  SIZE_BASED_CLEANUP_MODE = AUTO
);
';

EXEC sys.sp_executesql @sql;
"@
}

foreach ($db in $cfg.databases) {
  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "---- DB: $db ----"

  # 1) Optional apply changes
  if ($ApplyChanges.IsPresent) {
    try {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "APPLY | $db | READ_WRITE + COMPAT 160 + QUERY_STORE (2GB RW)"
      Invoke-Sql -ServerInstance $dest -Database "master" -Query (Get-ApplyChangesQuery -DbName $db) | Out-Null
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level OK -Message "APPLY OK | $db"
    }
    catch {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message "APPLY FAIL | $db | $($_.Exception.Message)"
      throw
    }
  }
  else {
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "APPLY | skipped (report-only)"
  }

  # 2) Always: DB status report
  try {
    $dbStatus = Invoke-Sql -ServerInstance $dest -Database "master" -Query (Get-DbStatusQuery -DbName $db) | Select-Object -First 1
    if ($dbStatus) {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message (
        "STATUS | $db | state={0} access={1} read_only={2} compat={3}" -f
          $dbStatus.state_desc, $dbStatus.user_access_desc, $dbStatus.is_read_only, $dbStatus.compatibility_level
      )
    } else {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level WARN -Message "STATUS | $db | no row returned (db missing?)"
    }
  } catch {
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level WARN -Message "STATUS | $db | failed to read status: $($_.Exception.Message)"
  }

  # 3) Always: Query Store report (if Query Store view exists for this DB)
  try {
    $qs = Invoke-Sql -ServerInstance $dest -Database "master" -Query (Get-QueryStoreStatusQuery -DbName $db) | Select-Object -First 1
    if ($qs) {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message (
        "QUERY_STORE | $db | actual={0} desired={1} storage={2}/{3}MB reason={4}" -f
          $qs.actual_state_desc, $qs.desired_state_desc, $qs.current_storage_size_mb, $qs.max_storage_size_mb, $qs.readonly_reason
      )
    } else {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level WARN -Message "QUERY_STORE | $db | no row returned"
    }
  } catch {
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level WARN -Message "QUERY_STORE | $db | failed to read: $($_.Exception.Message)"
  }

  # 4) Always: orphaned users report (no auto-fix)
  try {
    $orphans = Invoke-Sql -ServerInstance $dest -Database "master" -Query (Get-OrphanedUsersQuery -DbName $db)
    if ($orphans -and $orphans.Count -gt 0) {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level WARN -Message "ORPHANS FOUND | $db | count=$($orphans.Count)"
      foreach ($o in $orphans) {
        Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level WARN -Message (
          "ORPHAN | DB={0} User={1} Type={2} Auth={3} DefaultSchema={4}" -f
            $o.DatabaseName, $o.UserName, $o.UserType, $o.authentication_type_desc, $o.default_schema_name
        )
      }
    } else {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level OK -Message "ORPHANS OK | $db | none found"
    }
  } catch {
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level WARN -Message "ORPHANS | $db | failed to check: $($_.Exception.Message)"
  }
}

Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level OK -Message "DONE"
Write-Host "`nLOG: $logFile"