<#
.SYNOPSIS
  PRECHECK for SQL migration:
  - Validate databases on SOURCE
  - (Optional) switch to READ_ONLY
  - Check free space on DESTINATION for target dataDir/logDir using current DB file sizes from SOURCE

.DESCRIPTION
  Space estimation WITHOUT backup:
  - Uses SOURCE sys.master_files.size (8KB pages) to estimate required MB for DATA and LOG separately.
  - Compares against DESTINATION volume free space for restoreOptions.dataDir and restoreOptions.logDir.
  - Adds safety margin percent.

.PARAMETER ConfigPath
  Path to config.json

.PARAMETER SetReadOnly
  If set, switches databases on SOURCE to READ_ONLY WITH ROLLBACK IMMEDIATE.
  Default: $false (so you can run precheck without changing anything)

.PARAMETER SafetyMarginPct
  Safety margin added to required MB.
  Default: 10.0

.EXAMPLE
  # precheck only (no read_only)
  .\precheck-migration.ps1 -ConfigPath .\config.json

.EXAMPLE
  # precheck + set read_only
  .\precheck-migration.ps1 -ConfigPath .\config.json -SetReadOnly

#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ConfigPath,

  [switch]$SetReadOnly,

  [decimal]$SafetyMarginPct = 10.0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Logging
function New-LogFile {
  param([string]$LogDir, [string]$Prefix = "precheck-migration")
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
#endregion

#region SQL helpers
function Assert-SqlServerModule {
  if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    throw "Brak modułu 'SqlServer'. Zainstaluj: Install-Module SqlServer -Scope CurrentUser"
  }
  Import-Module SqlServer -ErrorAction Stop
}

function Invoke-Sql {
  param(
    [Parameter(Mandatory=$true)][string]$ServerInstance,
    [Parameter(Mandatory=$true)][string]$Query,
    [string]$Database = "master"
  )
  Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $Query -QueryTimeout 0 -ErrorAction Stop
}
#endregion

#region Volume helpers (DESTINATION)
function Get-DestinationVolumes {
  param([string]$DestinationInstance)

  # Get all known mount points/volumes that SQL Server touches on destination
  $q = @"
SET NOCOUNT ON;

;WITH V AS (
  SELECT DISTINCT
    vs.volume_mount_point,
    vs.file_system_type,
    vs.total_bytes,
    vs.available_bytes
  FROM sys.master_files mf
  CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs
)
SELECT
  volume_mount_point,
  file_system_type,
  total_bytes,
  available_bytes,
  CAST(available_bytes / 1048576.0 AS decimal(18,2)) AS free_mb,
  CAST(total_bytes / 1048576.0 AS decimal(18,2)) AS total_mb
FROM V
ORDER BY volume_mount_point;
"@

  Invoke-Sql -ServerInstance $DestinationInstance -Query $q
}

function Normalize-Path([string]$p) {
  if (-not $p) { return $p }
  $p = $p.Trim()
  $p = $p -replace '/', '\'
  return $p
}

function Find-VolumeForPath {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)]$Volumes
  )
  $p = Normalize-Path $Path

  # Longest-prefix match: choose the most specific mount point that is a prefix of path
  $best = $null
  $bestLen = -1
  foreach ($v in $Volumes) {
    $mp = Normalize-Path $v.volume_mount_point
    if (-not $mp) { continue }

    # Ensure mount point ends with backslash for reliable prefix matching
    if ($mp[-1] -ne '\') { $mp = $mp + '\' }

    if ($p.ToLower().StartsWith($mp.ToLower())) {
      if ($mp.Length -gt $bestLen) {
        $best = $v
        $bestLen = $mp.Length
      }
    }
  }
  return $best
}
#endregion

#region Precheck queries (SOURCE)
function Get-DbInfoAndSessions {
  param([string]$SourceInstance, [string]$DbName)

  $dbEsc = $DbName.Replace("'", "''")
  $q = @"
SET NOCOUNT ON;

SELECT
  @@SERVERNAME AS ServerName,
  d.name       AS DatabaseName,
  d.state_desc,
  d.user_access_desc,
  d.is_read_only,
  d.is_in_standby,
  d.recovery_model_desc,
  d.compatibility_level
FROM sys.databases d
WHERE d.name = N'$dbEsc';

SELECT
  COUNT(*) AS ActiveUserSessions
FROM sys.dm_exec_sessions s
WHERE s.is_user_process = 1
  AND s.database_id = DB_ID(N'$dbEsc');
"@
  Invoke-Sql -ServerInstance $SourceInstance -Query $q
}

function Get-DbFileSizeMB {
  param([string]$SourceInstance, [string]$DbName)

  # size = number of 8KB pages. MB = size * 8 / 1024
  $dbEsc = $DbName.Replace("'", "''")
  $q = @"
SET NOCOUNT ON;

IF DB_ID(N'$dbEsc') IS NULL
BEGIN
  SELECT CAST(NULL AS sysname) AS DatabaseName, CAST(NULL AS nvarchar(10)) AS FileType, CAST(NULL AS decimal(18,2)) AS SizeMB;
  RETURN;
END

SELECT
  DB_NAME(mf.database_id) AS DatabaseName,
  CASE mf.type_desc WHEN 'ROWS' THEN 'DATA' WHEN 'LOG' THEN 'LOG' ELSE mf.type_desc END AS FileType,
  CAST(SUM(mf.size) * 8.0 / 1024.0 AS decimal(18,2)) AS SizeMB
FROM sys.master_files mf
WHERE mf.database_id = DB_ID(N'$dbEsc')
GROUP BY mf.database_id, CASE mf.type_desc WHEN 'ROWS' THEN 'DATA' WHEN 'LOG' THEN 'LOG' ELSE mf.type_desc END;
"@
  Invoke-Sql -ServerInstance $SourceInstance -Query $q
}

function Set-DatabaseReadOnly {
  param([string]$SourceInstance, [string]$DbName)

  $q = @"
SET NOCOUNT ON;
IF DB_ID(N'$($DbName.Replace("'", "''"))') IS NULL
  THROW 50000, 'Database not found.', 1;

ALTER DATABASE [$DbName] SET READ_ONLY WITH ROLLBACK IMMEDIATE;

SELECT name, state_desc, user_access_desc, is_read_only
FROM sys.databases
WHERE name = N'$($DbName.Replace("'", "''"))';
"@
  Invoke-Sql -ServerInstance $SourceInstance -Query $q
}
#endregion

# -------- MAIN --------
Assert-SqlServerModule

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "Nie znaleziono pliku config: $ConfigPath"
}

$cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

if (-not $cfg.source) { throw "Config: brak pola 'source'." }
if (-not $cfg.destination) { throw "Config: brak pola 'destination'." }
if (-not $cfg.databases -or $cfg.databases.Count -eq 0) { throw "Config: brak listy 'databases'." }
if (-not $cfg.restoreOptions.dataDir) { throw "Config: brak 'restoreOptions.dataDir'." }
if (-not $cfg.restoreOptions.logDir)  { throw "Config: brak 'restoreOptions.logDir'." }
if (-not $cfg.logOptions.logDir)      { throw "Config: brak 'logOptions.logDir'." }

$src = [string]$cfg.source
$dst = [string]$cfg.destination
$dataDir = [string]$cfg.restoreOptions.dataDir
$logDir  = [string]$cfg.restoreOptions.logDir

$alsoConsole = ($cfg.logOptions.alsoWriteToConsole -eq $true)
$logFile = New-LogFile -LogDir $cfg.logOptions.logDir

Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "START | PRECHECK | Source=$src | Destination=$dst"
Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "DBs=$($cfg.databases -join ', ')"
Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "Restore target dirs | dataDir=$dataDir | logDir=$logDir"
Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "Options | SafetyMarginPct=$SafetyMarginPct | SetReadOnly=$($SetReadOnly.IsPresent)"

# Get destination volumes (free space)
$dstVolumes = $null
try {
  $dstVolumes = Get-DestinationVolumes -DestinationInstance $dst
  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level OK -Message "DEST volumes read: $($dstVolumes.Count) row(s)"
} catch {
  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message "Nie mogę odczytać wolumenów na DEST (dm_os_volume_stats). $($_.Exception.Message)"
  throw
}

$dataVol = Find-VolumeForPath -Path $dataDir -Volumes $dstVolumes
$logVol  = Find-VolumeForPath -Path $logDir  -Volumes $dstVolumes

if (-not $dataVol) {
  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message "Nie znalazłem wolumenu dla dataDir=$dataDir na DEST (brak dopasowania mount point)."
  throw "Brak wolumenu dla dataDir."
}
if (-not $logVol) {
  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message "Nie znalazłem wolumenu dla logDir=$logDir na DEST (brak dopasowania mount point)."
  throw "Brak wolumenu dla logDir."
}

Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message ("DEST dataVol={0} freeMB={1}" -f $dataVol.volume_mount_point, $dataVol.free_mb)
Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message ("DEST logVol ={0} freeMB={1}" -f $logVol.volume_mount_point,  $logVol.free_mb)

$overallOk = $true

foreach ($db in $cfg.databases) {
  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "---- DB: $db ----"

  # 1) Basic DB checks on SOURCE
  $infoRows = $null
  try {
    $rows = Get-DbInfoAndSessions -SourceInstance $src -DbName $db
    $info = $rows | Where-Object { $_.PSObject.Properties.Name -contains 'DatabaseName' } | Select-Object -First 1
    $sess = $rows | Where-Object { $_.PSObject.Properties.Name -contains 'ActiveUserSessions' } | Select-Object -First 1

    if (-not $info) {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message "PRECHECK FAIL | $db | Brak w sys.databases (baza nie istnieje)."
      $overallOk = $false
      continue
    }

    $active = 0
    if ($sess) { $active = [int]$sess.ActiveUserSessions }

    $fail = New-Object System.Collections.Generic.List[string]
    if ($info.state_desc -ne 'ONLINE') { $fail.Add("state_desc=$($info.state_desc)") }
    if ($info.user_access_desc -eq 'SINGLE_USER') { $fail.Add("user_access_desc=SINGLE_USER") }
    if ($info.is_in_standby -eq $true) { $fail.Add("is_in_standby=1") }

    if ($fail.Count -gt 0) {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message "PRECHECK FAIL | $db | $($fail -join '; ')"
      $overallOk = $false
      continue
    } else {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level OK -Message "PRECHECK OK | $db | ActiveSessions=$active | ReadOnly=$($info.is_read_only)"
    }
  } catch {
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message "PRECHECK EXCEPTION | $db | $($_.Exception.Message)"
    $overallOk = $false
    continue
  }

  # 2) Estimate required space from SOURCE current file sizes
  $sizes = Get-DbFileSizeMB -SourceInstance $src -DbName $db
  $dataMB = ($sizes | Where-Object { $_.FileType -eq 'DATA' } | Select-Object -First 1).SizeMB
  $logMB  = ($sizes | Where-Object { $_.FileType -eq 'LOG'  } | Select-Object -First 1).SizeMB

  if ($null -eq $dataMB) { $dataMB = 0 }
  if ($null -eq $logMB)  { $logMB  = 0 }

  $dataReq = [decimal]$dataMB * (1 + ($SafetyMarginPct / 100))
  $logReq  = [decimal]$logMB  * (1 + ($SafetyMarginPct / 100))

  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message ("ESTIMATE | $db | dataMB={0} logMB={1} | margin={2}% => dataReqMB={3} logReqMB={4}" -f $dataMB, $logMB, $SafetyMarginPct, [math]::Round($dataReq,2), [math]::Round($logReq,2))

  # 3) Compare against DEST free space (on target volumes)
  $dataFree = [decimal]$dataVol.free_mb
  $logFree  = [decimal]$logVol.free_mb

  $canData = ($dataFree -ge $dataReq)
  $canLog  = ($logFree  -ge $logReq)

  if ($canData) {
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level OK -Message ("SPACE OK | DATA | vol={0} freeMB={1} reqMB={2}" -f $dataVol.volume_mount_point, $dataFree, [math]::Round($dataReq,2))
  } else {
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message ("SPACE FAIL | DATA | vol={0} freeMB={1} reqMB={2}" -f $dataVol.volume_mount_point, $dataFree, [math]::Round($dataReq,2))
    $overallOk = $false
  }

  if ($canLog) {
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level OK -Message ("SPACE OK | LOG  | vol={0} freeMB={1} reqMB={2}" -f $logVol.volume_mount_point, $logFree, [math]::Round($logReq,2))
  } else {
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message ("SPACE FAIL | LOG  | vol={0} freeMB={1} reqMB={2}" -f $logVol.volume_mount_point, $logFree, [math]::Round($logReq,2))
    $overallOk = $false
  }

  # 4) Optional: switch to READ_ONLY on SOURCE
  if ($SetReadOnly.IsPresent) {
    try {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "READ_ONLY | switching $db on SOURCE (ROLLBACK IMMEDIATE)..."
      $r = Set-DatabaseReadOnly -SourceInstance $src -DbName $db | Select-Object -First 1
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level OK -Message "READ_ONLY OK | $db | state=$($r.state_desc) access=$($r.user_access_desc) is_read_only=$($r.is_read_only)"
    } catch {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message "READ_ONLY FAIL | $db | $($_.Exception.Message)"
      $overallOk = $false
    }
  } else {
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "READ_ONLY | skipped (SetReadOnly not specified)"
  }
}

Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "SUMMARY | overallOk=$overallOk"
if ($overallOk) {
  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level OK -Message "DONE | PRECHECK PASSED"
  Write-Host "`nLOG: $logFile"
  exit 0
} else {
  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message "DONE | PRECHECK FAILED"
  Write-Host "`nLOG: $logFile"
  exit 2
}
