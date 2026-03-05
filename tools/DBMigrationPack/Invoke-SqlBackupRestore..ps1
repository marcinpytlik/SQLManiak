#requires -Version 5.1
<#
.SYNOPSIS
  Backup DB on source and restore on destination based on JSON config (parallel jobs).
.DESCRIPTION
  Reads config.json with source, destination, backuppath (and options),
  performs backup on source to backuppath and restores on destination.
  Runs per-database in parallel using ThreadJobs.
  Logs:
   - run log: run_yyyyMMdd_HHmmss.log
   - per DB log: <DB>_yyyyMMdd_HHmmss.log
  Includes connection identity: @@SERVERNAME, HOST_NAME(), ORIGINAL_LOGIN()
  Dumps RESTORE HEADERONLY to DB log after backup.
#>

param(
  [Parameter(Mandatory)]
  [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Import-RequiredModules {
  if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    throw "Brak modułu SqlServer. Zainstaluj: Install-Module SqlServer -Scope CurrentUser"
  }
  Import-Module SqlServer -ErrorAction Stop

  if (-not (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)) {
    if (-not (Get-Module -ListAvailable -Name ThreadJob)) {
      throw "Brak Start-ThreadJob. Zainstaluj: Install-Module ThreadJob -Scope CurrentUser"
    }
    Import-Module ThreadJob -ErrorAction Stop
  }
}

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function New-ConnParams {
  param(
    [string]$ServerInstance,
    $CredCfg
  )

  $p = @{
    ServerInstance     = $ServerInstance
    QueryTimeout       = 0
    ConnectionTimeout  = 15
    ErrorAction        = "Stop"
  }

  # Default: Windows Auth
  if ($null -ne $CredCfg -and $CredCfg.type -and $CredCfg.type.ToLower() -eq "sql") {
    # Safer than plaintext in JSON: PSCredential stored as CLIXML
    if (-not $CredCfg.credentialPath) {
      throw "Dla credential type=sql podaj credentialPath do pliku .clixml (Export-Clixml)."
    }
    $cred = Import-Clixml -Path $CredCfg.credentialPath
    $p.Credential = $cred
  }

  return $p
}

function Get-DatabaseList {
  param($Cfg, $SourceConn)

  # Obsłuż databases jako: string, array, null
  if ($Cfg.PSObject.Properties.Name -contains 'databases' -and $null -ne $Cfg.databases) {
    $dbsFromCfg = @($Cfg.databases) | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -ne "" }
    if ($dbsFromCfg.Count -gt 0) {
      return $dbsFromCfg
    }
  }

  $q = @"
SELECT name
FROM sys.databases
WHERE database_id > 4
  AND state_desc = 'ONLINE'
  AND is_read_only = 0;
"@
  return @((Invoke-Sqlcmd @SourceConn -Database master -Query $q).name)
}

function Write-RunLog {
  param(
    [string]$LogFile,
    [string]$Message,
    [switch]$ToConsole
  )
  $line = "{0} | {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $Message
  Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
  if ($ToConsole) { Write-Host $line }
}

# --- MAIN ---
Import-RequiredModules

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "Nie znaleziono pliku config: $ConfigPath"
}
$cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

if (-not $cfg.source -or -not $cfg.destination -or -not $cfg.backuppath) {
  throw "Config musi mieć: source, destination, backuppath."
}

# Log config
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = $cfg.logOptions.logDir
if (-not $logDir) { $logDir = Join-Path $scriptDir "logs" }
Ensure-Dir -Path $logDir

$alsoConsole = $true
if ($null -ne $cfg.logOptions -and $null -ne $cfg.logOptions.alsoWriteToConsole) {
  $alsoConsole = [bool]$cfg.logOptions.alsoWriteToConsole
}

$runTs = Get-Date -Format "yyyyMMdd_HHmmss"
$runLog = Join-Path $logDir ("run_{0}.log" -f $runTs)

Write-RunLog -LogFile $runLog -Message "START | source=$($cfg.source) destination=$($cfg.destination) backuppath=$($cfg.backuppath)" -ToConsole:($alsoConsole)

# Create backup folder locally if needed (note: SQL Server service accounts need access for UNC)
Ensure-Dir -Path $cfg.backuppath

$sourceConn = New-ConnParams -ServerInstance $cfg.source -CredCfg $cfg.sourceCredential
$destConn   = New-ConnParams -ServerInstance $cfg.destination -CredCfg $cfg.destinationCredential

$dbs = @(Get-DatabaseList -Cfg $cfg -SourceConn $sourceConn)
if ($dbs.Count -eq 0) { throw "Brak baz do przetworzenia." }

$backupOptions  = $cfg.backupOptions
if ($null -eq $backupOptions) {
  $backupOptions = [pscustomobject]@{ copyOnly=$true; compress=$true; checksum=$true; init=$true; stats=10 }
}

$restoreOptions = $cfg.restoreOptions
if ($null -eq $restoreOptions) {
  $restoreOptions = [pscustomobject]@{ replace=$true; recover=$true; moveFiles=$true; dataDir="D:\SQLData"; logDir="E:\SQLLog" }
}

$throttle = [int]( if ($cfg.PSObject.Properties.Name -contains 'throttleLimit' -and $null -ne $cfg.throttleLimit) { $cfg.throttleLimit } else { 2 } )

Write-RunLog -LogFile $runLog -Message ("INFO  | db_count={0} throttle={1} logDir={2}" -f $dbs.Count,$throttle,$logDir) -ToConsole:($alsoConsole)

$jobs = @()

foreach ($db in $dbs) {
  $jobs += Start-ThreadJob -ThrottleLimit $throttle -Name "BkpRst-$db" -ScriptBlock {
    param($DbName,$Cfg,$SourceConn,$DestConn,$BackupOptions,$RestoreOptions,$LogDir,$AlsoConsole)

    Import-Module SqlServer -ErrorAction Stop

    function Write-DbLog {
      param([string]$File,[string]$Msg,[switch]$ToConsole)
      $line = "{0} | {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $Msg
      Add-Content -LiteralPath $File -Value $line -Encoding UTF8
      if ($ToConsole) { Write-Host $line }
    }

    function Get-ConnIdentity {
      param($Conn)
      $q = "SELECT @@SERVERNAME AS ServerName, HOST_NAME() AS HostName, ORIGINAL_LOGIN() AS OriginalLogin;"
      Invoke-Sqlcmd @Conn -Database master -Query $q | Select-Object -First 1
    }

    function Dump-RestoreHeaderOnlyToLog {
      param(
        [string]$BackupFile,
        $Conn,
        [string]$DbLog,
        [switch]$ToConsole
      )

      Write-DbLog -File $DbLog -Msg "INFO  | RESTORE HEADERONLY begin" -ToConsole:$ToConsole

      $q = "RESTORE HEADERONLY FROM DISK = N'$BackupFile';"
      $hdr = @(Invoke-Sqlcmd @Conn -Database master -Query $q)

      if ($hdr.Count -eq 0) {
        Write-DbLog -File $DbLog -Msg "INFO  | RESTORE HEADERONLY returned 0 rows" -ToConsole:$ToConsole
        return
      }

      $pick = $hdr | Select-Object -First 1 | Select-Object `
        BackupName, BackupDescription, BackupTypeDescription, ExpirationDate, Compressed, Position, DeviceType, `
        DatabaseName, DatabaseVersion, DatabaseCreationDate, BackupStartDate, BackupFinishDate, FirstLSN, LastLSN, CheckpointLSN, DatabaseBackupLSN, `
        RecoveryModel, Collation, HasBackupChecksums, IsCopyOnly, IsDamaged, IsReadOnly, `
        ServerName, MachineName, InstanceName, SoftwareVersionMajor, SoftwareVersionMinor, SoftwareVersionBuild, `
        EncryptorType, KeyAlgorithm, EncryptorThumbprint

      Write-DbLog -File $DbLog -Msg "INFO  | RESTORE HEADERONLY (selected fields):" -ToConsole:$ToConsole
      foreach ($p in $pick.PSObject.Properties) {
        $val = $p.Value
        if ($val -is [datetime]) { $val = $val.ToString("yyyy-MM-dd HH:mm:ss") }
        Write-DbLog -File $DbLog -Msg ("HDR   | {0}={1}" -f $p.Name, $val) -ToConsole:$ToConsole
      }

      Write-DbLog -File $DbLog -Msg "INFO  | RESTORE HEADERONLY end" -ToConsole:$ToConsole
    }

    $safeDb = $DbName.Replace("[","").Replace("]","")
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $dbLog = Join-Path $LogDir ("{0}_{1}.log" -f $safeDb,$ts)
    $backupFile = Join-Path $Cfg.backuppath ("{0}_{1}.bak" -f $safeDb,$ts)

    $result = [ordered]@{
      Database     = $DbName
      BackupFile   = $backupFile
      DbLog        = $dbLog
      Started      = (Get-Date)
      BackupOk     = $false
      RestoreOk    = $false
      Error        = $null
      DurationSec  = $null
      Finished     = $null
    }

    Write-DbLog -File $dbLog -Msg ("START | db={0} backupFile={1}" -f $DbName,$backupFile) -ToConsole:($AlsoConsole)

    # Connection identity log
    try {
      $srcId = Get-ConnIdentity -Conn $SourceConn
      Write-DbLog -File $dbLog -Msg ("SRCID | @@SERVERNAME={0} HOST_NAME()={1} ORIGINAL_LOGIN()={2}" -f $srcId.ServerName,$srcId.HostName,$srcId.OriginalLogin) -ToConsole:($AlsoConsole)
    } catch {
      Write-DbLog -File $dbLog -Msg ("SRCID | ERROR | {0}" -f $_.Exception.Message) -ToConsole:($AlsoConsole)
    }

    try {
      $dstId = Get-ConnIdentity -Conn $DestConn
      Write-DbLog -File $dbLog -Msg ("DSTID | @@SERVERNAME={0} HOST_NAME()={1} ORIGINAL_LOGIN()={2}" -f $dstId.ServerName,$dstId.HostName,$dstId.OriginalLogin) -ToConsole:($AlsoConsole)
    } catch {
      Write-DbLog -File $dbLog -Msg ("DSTID | ERROR | {0}" -f $_.Exception.Message) -ToConsole:($AlsoConsole)
    }

    try {
      # BACKUP
      Write-DbLog -File $dbLog -Msg "STEP  | BACKUP begin" -ToConsole:($AlsoConsole)

      $copyOnly  = ($BackupOptions.copyOnly  -eq $true) ? "COPY_ONLY," : ""
      $compress  = ($BackupOptions.compress  -eq $true) ? "COMPRESSION," : "NO_COMPRESSION,"
      $checksum  = ($BackupOptions.checksum  -eq $true) ? "CHECKSUM," : "NO_CHECKSUM,"
      $init      = ($BackupOptions.init      -eq $true) ? "INIT," : "NOINIT,"
      $stats     = ($BackupOptions.stats) ? "STATS = $($BackupOptions.stats)," : ""

      $with = @($copyOnly,$compress,$checksum,$init,$stats) -join " "
      $with = $with.Trim()
      if ($with.EndsWith(",")) { $with = $with.TrimEnd(",") }

      $qBackup = @"
BACKUP DATABASE [$DbName]
TO DISK = N'$backupFile'
WITH $with;
"@
      Invoke-Sqlcmd @SourceConn -Database master -Query $qBackup | Out-Null
      $result.BackupOk = $true
      Write-DbLog -File $dbLog -Msg "STEP  | BACKUP ok" -ToConsole:($AlsoConsole)

      # HEADERONLY on destination
      Dump-RestoreHeaderOnlyToLog -BackupFile $backupFile -Conn $DestConn -DbLog $dbLog -ToConsole:($AlsoConsole)

      # RESTORE
      Write-DbLog -File $dbLog -Msg "STEP  | RESTORE begin" -ToConsole:($AlsoConsole)

      $replace = ($RestoreOptions.replace -eq $true) ? "REPLACE," : ""
      $recover = ($RestoreOptions.recover -eq $true) ? "RECOVERY," : "NORECOVERY,"

      $moveClause = ""
      if ($RestoreOptions.moveFiles -eq $true) {
        $qFileList = "RESTORE FILELISTONLY FROM DISK = N'$backupFile';"
        $files = @(Invoke-Sqlcmd @DestConn -Database master -Query $qFileList)

        $dataDir = $RestoreOptions.dataDir
        $logDir2 = $RestoreOptions.logDir
        if (-not $dataDir -or -not $logDir2) {
          throw "restoreOptions.moveFiles=true wymaga dataDir i logDir."
        }

        $moves = New-Object System.Collections.Generic.List[string]
        foreach ($f in $files) {
          $logical = $f.LogicalName
          $type    = $f.Type  # D=data, L=log
          $base    = [System.IO.Path]::GetFileName($f.PhysicalName)
          $targetDir = ($type -eq "L") ? $logDir2 : $dataDir
          $target = Join-Path $targetDir $base
          $moves.Add("MOVE N'$logical' TO N'$target'")
        }
        $moveClause = ($moves -join ",`n    ") + ","
      }

      $withParts = @(
        $replace,
        $recover,
        $moveClause
      ) -join "`n    "
      $withParts = $withParts.Trim()
      if ($withParts.EndsWith(",")) { $withParts = $withParts.TrimEnd(",") }

      $qRestore = @"
RESTORE DATABASE [$DbName]
FROM DISK = N'$backupFile'
WITH
    $withParts;
"@
      Invoke-Sqlcmd @DestConn -Database master -Query $qRestore | Out-Null
      $result.RestoreOk = $true
      Write-DbLog -File $dbLog -Msg "STEP  | RESTORE ok" -ToConsole:($AlsoConsole)

      Write-DbLog -File $dbLog -Msg "DONE  | success" -ToConsole:($AlsoConsole)
    }
    catch {
      $result.Error = $_.Exception.Message
      Write-DbLog -File $dbLog -Msg ("ERROR | {0}" -f $result.Error) -ToConsole:($AlsoConsole)
    }
    finally {
      $result.Finished = (Get-Date)
      $result.DurationSec = [math]::Round((New-TimeSpan -Start $result.Started -End $result.Finished).TotalSeconds,2)
      Write-DbLog -File $dbLog -Msg ("END   | durationSec={0}" -f $result.DurationSec) -ToConsole:($AlsoConsole)
    }

    [pscustomobject]$result
  } -ArgumentList $db,$cfg,$sourceConn,$destConn,$backupOptions,$restoreOptions,$logDir,$alsoConsole
}

$results = @(Receive-Job -Job $jobs -Wait -AutoRemoveJob)

# Summary to run log
foreach ($r in ($results | Sort-Object Database)) {
  $status = if ($r.BackupOk -and $r.RestoreOk) { "OK" } else { "FAIL" }
  Write-RunLog -LogFile $runLog -Message ("RESULT| {0} | backup={1} restore={2} dur={3}s | dbLog={4} | {5}" -f $r.Database,$r.BackupOk,$r.RestoreOk,$r.DurationSec,$r.DbLog,$status) -ToConsole:($alsoConsole)
  if ($r.Error) {
    Write-RunLog -LogFile $runLog -Message ("ERROR | {0} | {1}" -f $r.Database,$r.Error) -ToConsole:($alsoConsole)
  }
}

$results | Sort-Object Database | Format-Table -AutoSize

$failed = @($results | Where-Object { -not $_.BackupOk -or -not $_.RestoreOk })
if ($failed.Count -gt 0) {
  Write-RunLog -LogFile $runLog -Message ("END   | FAILED | dbs={0}" -f (($failed.Database) -join ", ")) -ToConsole:($alsoConsole)
  Write-Error ("Niektóre bazy poległy: {0}" -f (($failed.Database) -join ", "))
  exit 2
}

Write-RunLog -LogFile $runLog -Message "END   | SUCCESS | wszystkie bazy OK" -ToConsole:($alsoConsole)
Write-Host "`nOK: wszystkie bazy zbackupowane i odtworzone."
Write-Host "Run log: $runLog"