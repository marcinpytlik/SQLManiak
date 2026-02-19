<#
.SYNOPSIS
  PRECHECK for SQL migration (SOURCE + DEST readiness):
  - Validate DBs on SOURCE
  - Estimate space needed on DEST (dataDir/logDir) using current DB file sizes from SOURCE (+ safety margin)
  - Feature snapshot: components/features used by DB (CDC, Broker, TDE, QS, FTS, CLR, In-Memory, FILESTREAM/FileTable, Replication, etc.)
  - DEST instance snapshot: verifies instance-level capabilities (Full-Text installed, CLR enabled, FILESTREAM effective level, Agent status, containment auth, etc.)
  - Optional: set DBs on SOURCE to READ_ONLY WITH ROLLBACK IMMEDIATE

.USAGE
  # Report-only (safe, no changes)
  .\precheck-migration.ps1 -ConfigPath .\config.json

  # Report + set READ_ONLY on source
  .\precheck-migration.ps1 -ConfigPath .\config.json -SetReadOnly

.PARAMETER SafetyMarginPct
  Safety margin added to required MB (default 10%)
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

#region DEST: Volumes + instance snapshot
function Get-DestinationVolumes {
  param([string]$DestinationInstance)

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
  CAST(total_bytes / 1048576.0 AS decimal(18,2))     AS total_mb
FROM V
ORDER BY volume_mount_point;
"@
  Invoke-Sql -ServerInstance $DestinationInstance -Query $q
}

function Normalize-Path([string]$p) {
  if (-not $p) { return $p }
  ($p.Trim() -replace '/', '\')
}

function Find-VolumeForPath {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)]$Volumes
  )
  $p = Normalize-Path $Path

  $best = $null
  $bestLen = -1
  foreach ($v in $Volumes) {
    $mp = Normalize-Path $v.volume_mount_point
    if (-not $mp) { continue }
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

function Get-InstanceSnapshot {
  param([string]$Instance)

  $q = @"
SET NOCOUNT ON;

DECLARE @FullTextInstalled int = CAST(SERVERPROPERTY('IsFullTextInstalled') AS int);
DECLARE @HadrEnabled int = CAST(SERVERPROPERTY('IsHadrEnabled') AS int);

SELECT
  @@SERVERNAME AS ServerName,
  CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(50)) AS ProductVersion,
  CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(50)) AS ProductLevel,
  CAST(SERVERPROPERTY('Edition') AS nvarchar(200)) AS Edition,
  @FullTextInstalled AS IsFullTextInstalled,
  @HadrEnabled AS IsHadrEnabled,
  CAST(SERVERPROPERTY('FilestreamConfiguredLevel') AS int) AS FilestreamConfiguredLevel,
  CAST(SERVERPROPERTY('FilestreamEffectiveLevel') AS int) AS FilestreamEffectiveLevel;

SELECT
  name,
  CAST(value_in_use AS int) AS value_in_use
FROM sys.configurations
WHERE name IN (
  'clr enabled',
  'contained database authentication',
  'xp_cmdshell'
);

-- SQL Server Agent status (requires VIEW SERVER STATE)
SELECT
  servicename,
  status_desc,
  startup_type_desc,
  last_startup_time
FROM sys.dm_server_services
WHERE servicename LIKE 'SQL Server Agent%';
"@
  Invoke-Sql -ServerInstance $Instance -Database "master" -Query $q
}

function Convert-InstanceSnapshot {
  param($Rows)

  $main = $Rows | Where-Object { $_.PSObject.Properties.Name -contains 'IsFullTextInstalled' } | Select-Object -First 1
  $cfg  = $Rows | Where-Object { $_.PSObject.Properties.Name -contains 'value_in_use' -and $_.name }
  $svc  = $Rows | Where-Object { $_.PSObject.Properties.Name -contains 'servicename' } | Select-Object -First 1

  $cfgMap = @{}
  foreach ($c in $cfg) { $cfgMap[$c.name] = [int]$c.value_in_use }

  [pscustomobject]@{
    ServerName = $main.ServerName
    ProductVersion = $main.ProductVersion
    ProductLevel = $main.ProductLevel
    Edition = $main.Edition
    IsFullTextInstalled = [int]$main.IsFullTextInstalled
    IsHadrEnabled = [int]$main.IsHadrEnabled
    FilestreamConfiguredLevel = [int]$main.FilestreamConfiguredLevel
    FilestreamEffectiveLevel  = [int]$main.FilestreamEffectiveLevel
    ClrEnabled = ($cfgMap['clr enabled'] -as [int])
    ContainedDbAuth = ($cfgMap['contained database authentication'] -as [int])
    XpCmdShell = ($cfgMap['xp_cmdshell'] -as [int])
    AgentStatus = if ($svc) { $svc.status_desc } else { $null }
    AgentStartup = if ($svc) { $svc.startup_type_desc } else { $null }
    AgentLastStart = if ($svc) { $svc.last_startup_time } else { $null }
  }
}
#endregion

#region SOURCE: DB checks + sizes + feature snapshot
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
  Invoke-Sql -ServerInstance $SourceInstance -Database "master" -Query $q
}

function Get-DbFileSizeMB {
  param([string]$SourceInstance, [string]$DbName)

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
  Invoke-Sql -ServerInstance $SourceInstance -Database "master" -Query $q
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
  Invoke-Sql -ServerInstance $SourceInstance -Database "master" -Query $q
}

function Get-DbFeatureSnapshot {
  param([string]$SourceInstance, [string]$DbName)

  $dbEsc = $DbName.Replace("'", "''")

  $q = @"
SET NOCOUNT ON;

IF DB_ID(N'$dbEsc') IS NULL
BEGIN
  SELECT CAST(N'$dbEsc' AS sysname) AS DatabaseName, CAST(1 AS bit) AS DbMissing;
  RETURN;
END

DECLARE @db sysname = N'$dbEsc';

DECLARE @sql nvarchar(max) = N'
USE ' + QUOTENAME(@db) + N';

;WITH Rep AS (
  SELECT TOP(1)
    d.is_published,
    d.is_subscribed,
    d.is_merge_published,
    d.is_distributor
  FROM sys.databases d WHERE d.name = DB_NAME()
),
FT AS (
  SELECT
    IsFullTextEnabled = CAST(DATABASEPROPERTYEX(DB_NAME(), ''IsFullTextEnabled'') AS int),
    FulltextCatalogs  = (SELECT COUNT(*) FROM sys.fulltext_catalogs),
    FulltextIndexes   = (SELECT COUNT(*) FROM sys.fulltext_indexes)
),
CLR AS (
  SELECT
    UserAssemblies = (SELECT COUNT(*) FROM sys.assemblies WHERE is_user_defined = 1),
    SignedAssemblies = (SELECT COUNT(*) FROM sys.assemblies WHERE is_user_defined = 1 AND is_signed = 1)
),
IM AS (
  SELECT
    MemoryOptimizedTables = (SELECT COUNT(*) FROM sys.tables WHERE is_memory_optimized = 1),
    HasMemoryOptimizedFG  = CASE WHEN EXISTS (SELECT 1 FROM sys.filegroups WHERE type = ''FX'') THEN 1 ELSE 0 END
),
FS AS (
  SELECT
    HasFileTable = CASE WHEN EXISTS (SELECT 1 FROM sys.filetables) THEN 1 ELSE 0 END
),
SEC AS (
  SELECT
    UserCertificates  = (SELECT COUNT(*) FROM sys.certificates WHERE name NOT LIKE ''##%##''),
    UserSymmetricKeys = (SELECT COUNT(*) FROM sys.symmetric_keys WHERE name NOT LIKE ''##%##'')
),
CDC AS (
  SELECT
    IsCdcEnabled = (SELECT CAST(is_cdc_enabled AS int) FROM sys.databases WHERE name = DB_NAME()),
    CdcCaptureInstances = CASE
      WHEN (SELECT is_cdc_enabled FROM sys.databases WHERE name = DB_NAME()) = 1
        THEN (SELECT COUNT(*) FROM cdc.change_tables)
      ELSE 0
    END
),
QS AS (
  SELECT
    IsQueryStoreOn = (SELECT CAST(is_query_store_on AS int) FROM sys.databases WHERE name = DB_NAME()),
    QsActualState  = (SELECT TOP(1) actual_state_desc FROM sys.database_query_store_options),
    QsDesiredState = (SELECT TOP(1) desired_state_desc FROM sys.database_query_store_options),
    QsMaxMB        = (SELECT TOP(1) max_storage_size_mb FROM sys.database_query_store_options)
)
SELECT
  @@SERVERNAME AS ServerName,
  DB_NAME() AS DatabaseName,

  d.state_desc,
  d.recovery_model_desc,
  d.compatibility_level,
  d.is_read_only,
  d.is_broker_enabled,
  d.service_broker_guid,
  d.is_encrypted,
  d.is_trustworthy_on,
  d.snapshot_isolation_state_desc,
  d.is_read_committed_snapshot_on,
  d.containment_desc,

  Rep.is_published,
  Rep.is_subscribed,
  Rep.is_merge_published,
  Rep.is_distributor,

  CDC.IsCdcEnabled,
  CDC.CdcCaptureInstances,

  FT.IsFullTextEnabled,
  FT.FulltextCatalogs,
  FT.FulltextIndexes,

  CLR.UserAssemblies,
  CLR.SignedAssemblies,

  IM.MemoryOptimizedTables,
  IM.HasMemoryOptimizedFG,

  FS.HasFileTable,

  SEC.UserCertificates,
  SEC.UserSymmetricKeys,

  QS.IsQueryStoreOn,
  QS.QsActualState,
  QS.QsDesiredState,
  QS.QsMaxMB

FROM sys.databases d
CROSS JOIN Rep
CROSS JOIN FT
CROSS JOIN CLR
CROSS JOIN IM
CROSS JOIN FS
CROSS JOIN SEC
CROSS JOIN CDC
CROSS JOIN QS
WHERE d.name = DB_NAME();
';

EXEC sys.sp_executesql @sql;
"@
  Invoke-Sql -ServerInstance $SourceInstance -Database "master" -Query $q
}
#endregion

#region Hints + DEST readiness checks
function Add-Hints {
  param([Parameter(Mandatory=$true)]$SnapRow)

  $h = New-Object System.Collections.Generic.List[string]

  if ($SnapRow.is_broker_enabled -eq 1) { $h.Add("Service Broker: ON → sprawdź procesy/brokery po cutover; NEW_BROKER/ENABLE_BROKER tylko świadomie.") }
  if ($SnapRow.IsCdcEnabled -eq 1) { $h.Add("CDC: ON → po migracji Agent + joby CDC; to często osobny krok.") }
  if (($SnapRow.IsFullTextEnabled -eq 1) -or ($SnapRow.FulltextIndexes -gt 0)) { $h.Add("Full-Text: wykryto → DEST musi mieć zainstalowany Full-Text.") }
  if ($SnapRow.UserAssemblies -gt 0) { $h.Add("CLR: są assemblies → na DEST zwykle potrzebne 'clr enabled'=1 i polityka security do CLR.") }
  if (($SnapRow.MemoryOptimizedTables -gt 0) -or ($SnapRow.HasMemoryOptimizedFG -eq 1)) { $h.Add("In-Memory OLTP: wykryto → upewnij się, że storage i filegroup MEMORY_OPTIMIZED_DATA jest poprawnie przeniesiony.") }
  if ($SnapRow.HasFileTable -eq 1) { $h.Add("FileTable/FILESTREAM: wykryto → DEST musi mieć FILESTREAM skonfigurowany na instancji/OS.") }
  if ($SnapRow.is_encrypted -eq 1) { $h.Add("TDE: ON → na DEST potrzebny certyfikat/klucz z master, inaczej restore/online nie wstanie.") }
  if (($SnapRow.UserCertificates -gt 0) -or ($SnapRow.UserSymmetricKeys -gt 0)) { $h.Add("Klucze/certyfikaty w DB: wykryto → sprawdź zależności (szyfrowanie/podpisy/broker).") }
  if (($SnapRow.is_published -eq 1) -or ($SnapRow.is_subscribed -eq 1) -or ($SnapRow.is_merge_published -eq 1) -or ($SnapRow.is_distributor -eq 1)) {
    $h.Add("Replikacja: wykryta → to zwykle osobny projekt migracji, nie tylko restore DB.")
  }
  if ($SnapRow.is_trustworthy_on -eq 1) { $h.Add("TRUSTWORTHY: ON → sprawdź czy potrzebne; po migracji może wymagać odtworzenia owner/login context.") }
  if ($SnapRow.containment_desc -and $SnapRow.containment_desc -ne 'NONE') { $h.Add("Containment: $($SnapRow.containment_desc) → sprawdź contained users i sposób auth aplikacji.") }
  if ($SnapRow.is_read_committed_snapshot_on -eq 1) { $h.Add("RCSI: ON → na DEST tempdb musi dać radę (wersjonowanie).") }

  if ($h.Count -eq 0) { $h.Add("Brak istotnych feature-flagów w typowych kategoriach (snapshot).") }
  return $h
}

function Check-DestReadiness {
  param(
    [Parameter(Mandatory=$true)][string]$DbName,
    [Parameter(Mandatory=$true)]$DbSnap,
    [Parameter(Mandatory=$true)]$DestSnap,
    [Parameter(Mandatory=$true)][string]$LogFile,
    [switch]$AlsoConsole
  )

  $ok = $true

  # Full-Text
  if ((($DbSnap.IsFullTextEnabled -eq 1) -or ($DbSnap.FulltextIndexes -gt 0)) -and ($DestSnap.IsFullTextInstalled -ne 1)) {
    Write-Log -Path $LogFile -AlsoConsole:$AlsoConsole -Level ERROR -Message "DEST CHECK FAIL | $DbName | Full-Text wymagany przez DB, ale na DEST IsFullTextInstalled=0"
    $ok = $false
  }

  # CLR
  if (($DbSnap.UserAssemblies -gt 0) -and ($DestSnap.ClrEnabled -ne 1)) {
    Write-Log -Path $LogFile -AlsoConsole:$AlsoConsole -Level ERROR -Message "DEST CHECK FAIL | $DbName | CLR assemblies w DB, ale na DEST 'clr enabled'=0"
    $ok = $false
  }

  # FILESTREAM / FileTable
  if (($DbSnap.HasFileTable -eq 1) -and ([int]$DestSnap.FilestreamEffectiveLevel -lt 1)) {
    Write-Log -Path $LogFile -AlsoConsole:$AlsoConsole -Level ERROR -Message "DEST CHECK FAIL | $DbName | FileTable/FILESTREAM wykryte, ale na DEST FilestreamEffectiveLevel < 1"
    $ok = $false
  }

  # CDC -> Agent strongly recommended
  if (($DbSnap.IsCdcEnabled -eq 1)) {
    if (-not $DestSnap.AgentStatus) {
      Write-Log -Path $LogFile -AlsoConsole:$AlsoConsole -Level WARN -Message "DEST CHECK WARN | $DbName | CDC w DB, ale Agent status na DEST = UNKNOWN (brak VIEW SERVER STATE?)"
    } elseif ($DestSnap.AgentStatus -ne 'Running') {
      Write-Log -Path $LogFile -AlsoConsole:$AlsoConsole -Level WARN -Message "DEST CHECK WARN | $DbName | CDC w DB, ale SQL Server Agent na DEST nie jest Running (status=$($DestSnap.AgentStatus))"
    }
  }

  # Containment auth
  if (($DbSnap.containment_desc -and $DbSnap.containment_desc -ne 'NONE') -and ($DestSnap.ContainedDbAuth -ne 1)) {
    Write-Log -Path $LogFile -AlsoConsole:$AlsoConsole -Level WARN -Message "DEST CHECK WARN | $DbName | Containment=$($DbSnap.containment_desc), ale na DEST 'contained database authentication'=0"
  }

  return $ok
}
#endregion

# -------- MAIN --------
Assert-SqlServerModule

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Nie znaleziono pliku config: $ConfigPath" }

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

# DEST instance snapshot
$dstSnap = $null
try {
  $dstSnapRows = Get-InstanceSnapshot -Instance $dst
  $dstSnap = Convert-InstanceSnapshot -Rows $dstSnapRows

  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message (
    "DEST SNAPSHOT | {0} | ver={1} {2} | edition={3} | FT={4} | CLR={5} | FILESTREAM(eff/conf)={6}/{7} | Agent={8} | HADR={9} | ContainedAuth={10}" -f
    $dstSnap.ServerName, $dstSnap.ProductVersion, $dstSnap.ProductLevel, $dstSnap.Edition,
    $dstSnap.IsFullTextInstalled, $dstSnap.ClrEnabled,
    $dstSnap.FilestreamEffectiveLevel, $dstSnap.FilestreamConfiguredLevel,
    ($dstSnap.AgentStatus ?? 'UNKNOWN'),
    $dstSnap.IsHadrEnabled,
    ($dstSnap.ContainedDbAuth ?? -1)
  )
} catch {
  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level WARN -Message "DEST SNAPSHOT WARN | Nie udało się pobrać pełnego snapshotu DEST: $($_.Exception.Message)"
  # continue, but some checks will be skipped
}

# DEST volumes
$dstVolumes = $null
$dataVol = $null
$logVol = $null
try {
  $dstVolumes = Get-DestinationVolumes -DestinationInstance $dst
  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level OK -Message "DEST volumes read: $($dstVolumes.Count) row(s)"

  $dataVol = Find-VolumeForPath -Path $dataDir -Volumes $dstVolumes
  $logVol  = Find-VolumeForPath -Path $logDir  -Volumes $dstVolumes

  if (-not $dataVol) { throw "Nie znalazłem wolumenu dla dataDir=$dataDir (mount point mismatch)." }
  if (-not $logVol)  { throw "Nie znalazłem wolumenu dla logDir=$logDir (mount point mismatch)." }

  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message ("DEST dataVol={0} freeMB={1}" -f $dataVol.volume_mount_point, $dataVol.free_mb)
  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message ("DEST logVol ={0} freeMB={1}" -f $logVol.volume_mount_point,  $logVol.free_mb)
} catch {
  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message "DEST VOLUME FAIL | $($_.Exception.Message)"
  throw
}

$overallOk = $true

foreach ($db in $cfg.databases) {
  Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "================ DB: $db ================"

  # 1) basic db checks
  $info = $null
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
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level OK -Message "PRECHECK OK | $db | ActiveSessions=$active | ReadOnly=$($info.is_read_only) | Recovery=$($info.recovery_model_desc) | Compat=$($info.compatibility_level)"
    }
  } catch {
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message "PRECHECK EXCEPTION | $db | $($_.Exception.Message)"
    $overallOk = $false
    continue
  }

  # 2) space estimate from SOURCE file sizes
  try {
    $sizes = Get-DbFileSizeMB -SourceInstance $src -DbName $db
    $dataMB = ($sizes | Where-Object { $_.FileType -eq 'DATA' } | Select-Object -First 1).SizeMB
    $logMB  = ($sizes | Where-Object { $_.FileType -eq 'LOG'  } | Select-Object -First 1).SizeMB
    if ($null -eq $dataMB) { $dataMB = 0 }
    if ($null -eq $logMB)  { $logMB  = 0 }

    $dataReq = [decimal]$dataMB * (1 + ($SafetyMarginPct / 100))
    $logReq  = [decimal]$logMB  * (1 + ($SafetyMarginPct / 100))

    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message ("ESTIMATE | dataMB={0} logMB={1} | margin={2}% => dataReqMB={3} logReqMB={4}" -f $dataMB, $logMB, $SafetyMarginPct, [math]::Round($dataReq,2), [math]::Round($logReq,2))

    $dataFree = [decimal]$dataVol.free_mb
    $logFree  = [decimal]$logVol.free_mb

    if ($dataFree -ge $dataReq) {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level OK -Message ("SPACE OK | DATA | vol={0} freeMB={1} reqMB={2}" -f $dataVol.volume_mount_point, $dataFree, [math]::Round($dataReq,2))
    } else {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message ("SPACE FAIL | DATA | vol={0} freeMB={1} reqMB={2}" -f $dataVol.volume_mount_point, $dataFree, [math]::Round($dataReq,2))
      $overallOk = $false
    }

    if ($logFree -ge $logReq) {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level OK -Message ("SPACE OK | LOG  | vol={0} freeMB={1} reqMB={2}" -f $logVol.volume_mount_point, $logFree, [math]::Round($logReq,2))
    } else {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message ("SPACE FAIL | LOG  | vol={0} freeMB={1} reqMB={2}" -f $logVol.volume_mount_point, $logFree, [math]::Round($logReq,2))
      $overallOk = $false
    }
  } catch {
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level ERROR -Message "SPACE ESTIMATE EXCEPTION | $db | $($_.Exception.Message)"
    $overallOk = $false
  }

  # 3) DB feature snapshot
  $snap = $null
  try {
    $snap = Get-DbFeatureSnapshot -SourceInstance $src -DbName $db | Select-Object -First 1
    if (-not $snap -or ($snap.PSObject.Properties.Name -contains 'DbMissing' -and $snap.DbMissing -eq 1)) {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level WARN -Message "FEATURE SNAPSHOT | $db | brak danych (db missing?)"
    } else {
      Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message ("FEATURES | Broker={0} CDC={1} (inst={2}) FT={3} (idx={4}) CLR.Assemblies={5} InMemoryTables={6} FileTable={7} Rep(pub/sub/merge/dist)={8}/{9}/{10}/{11} TDE={12} QS={13}({14}->{15}, maxMB={16}) RCSI={17} TRUSTWORTHY={18} Containment={19}" -f
        $snap.is_broker_enabled,
        $snap.IsCdcEnabled, $snap.CdcCaptureInstances,
        $snap.IsFullTextEnabled, $snap.FulltextIndexes,
        $snap.UserAssemblies,
        $snap.MemoryOptimizedTables,
        $snap.HasFileTable,
        $snap.is_published, $snap.is_subscribed, $snap.is_merge_published, $snap.is_distributor,
        $snap.is_encrypted,
        $snap.IsQueryStoreOn, $snap.QsActualState, $snap.QsDesiredState, $snap.QsMaxMB,
        $snap.is_read_committed_snapshot_on,
        $snap.is_trustworthy_on,
        $snap.containment_desc
      )

      foreach ($x in (Add-Hints -SnapRow $snap)) {
        Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message ("HINT | {0}" -f $x)
      }
    }
  } catch {
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level WARN -Message "FEATURE SNAPSHOT FAILED | $db | $($_.Exception.Message)"
  }

  # 4) DEST readiness checks driven by DB features
  if ($snap -and $dstSnap) {
    $readyOk = Check-DestReadiness -DbName $db -DbSnap $snap -DestSnap $dstSnap -LogFile $logFile -AlsoConsole:$alsoConsole
    if (-not $readyOk) { $overallOk = $false }
  } elseif ($snap -and -not $dstSnap) {
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level WARN -Message "DEST CHECK SKIPPED | $db | brak snapshotu DEST (nie wszystkie porównania dostępne)."
  }

  # 5) Optional READ_ONLY on SOURCE
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
    Write-Log -Path $logFile -AlsoConsole:$alsoConsole -Level INFO -Message "READ_ONLY | skipped (dry-run)"
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
