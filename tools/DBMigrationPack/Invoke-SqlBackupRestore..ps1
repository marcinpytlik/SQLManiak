#requires -Version 5.1
<#
.SYNOPSIS
  Backup DB on source and restore on destination based on JSON config (parallel jobs).
.DESCRIPTION
  Offline-friendly, PS 5.1 hardened:
  - Forces TLS 1.2 (best effort)
  - Uses Invoke-Sqlcmd with explicit Encrypt/TrustServerCertificate (configurable)
  - Runs per-database in parallel using ThreadJob
  - Robust logging + full error diagnostics
  - Logs full BACKUP/RESTORE T-SQL commands into per-DB logs
  - Preflight: logs SQL Server service accounts + tests SQL-visible access to paths
  - -WhatIf: does NOT run BACKUP/RESTORE; performs only preflight + logs intended T-SQL
.NOTES
  Important: RESTORE paths must exist from SQL Server perspective.
  Do NOT use Join-Path for MOVE targets (it validates local PS drives). We build strings instead.
#>

param(
  [Parameter(Mandatory)]
  [string]$ConfigPath,

  [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

# -------------------- Helpers --------------------

function Import-RequiredModules {
  if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    throw "Brak modułu SqlServer. Zainstaluj offline lub: Install-Module SqlServer -Scope CurrentUser"
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
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Write-RunLog {
  param(
    [Parameter(Mandatory)][string]$LogFile,
    [Parameter(Mandatory)][string]$Message,
    [switch]$ToConsole
  )
  $line = "{0} | {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $Message
  Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
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
    $stack = ($ex.StackTrace -split "`r?`n" | Select-Object -First 15) -join " | "
  }

  [pscustomobject]@{
    Message  = if ($null -ne $ex) { $ex.Message } else { $Err.ToString() }
    Type     = if ($null -ne $ex) { $ex.GetType().FullName } else { $null }
    Script   = $script
    LineNo   = $lineNo
    Line     = $lineText
    Stack    = $stack
  }
}

function Normalize-DbListFromConfig {
  param($Cfg)
  if ($Cfg.PSObject.Properties.Name -notcontains 'databases') { return @() }
  if ($null -eq $Cfg.databases) { return @() }

  @($Cfg.databases) |
    ForEach-Object { if ($null -eq $_) { $null } else { $_.ToString().Trim() } } |
    Where-Object { $_ -and $_ -ne "" }
}

function New-ConnParams {
  param(
    [Parameter(Mandatory)][string]$ServerInstance,
    $CredCfg,
    $ConnOptions
  )

  $p = @{
    ServerInstance     = $ServerInstance
    QueryTimeout       = 0
    ConnectionTimeout  = 30
    ErrorAction        = "Stop"
  }

  $p.Encrypt = "Optional"
  $p.TrustServerCertificate = $true

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

  # Default: Windows Auth
  if ($null -ne $CredCfg -and $CredCfg.type -and $CredCfg.type.ToLower() -eq "sql") {
    if (-not $CredCfg.credentialPath) { throw "Dla credential type=sql podaj credentialPath do .clixml (Export-Clixml)." }
    $p.Credential = Import-Clixml -Path $CredCfg.credentialPath
  }

  return $p
}

function Get-DatabaseList {
  param($Cfg, $SourceConn)

  $fromCfg = Normalize-DbListFromConfig -Cfg $Cfg
  if (@($fromCfg).Count -gt 0) { return @($fromCfg) }

  $q = @"
SELECT name
FROM sys.databases
WHERE database_id > 4
  AND state_desc = 'ONLINE'
  AND is_read_only = 0;
"@
  return @((Invoke-Sqlcmd @SourceConn -Database master -Query $q).name)
}

function Get-ServerServices {
  param([Parameter(Mandatory)]$Conn)
  $q = @"
SELECT servicename, startup_type_desc, status_desc, service_account
FROM sys.dm_server_services
ORDER BY servicename;
"@
  return @(Invoke-Sqlcmd @Conn -Database master -Query $q)
}

function Get-SqlVisibleDrives {
  param([Parameter(Mandatory)]$Conn)
  try { return @(Invoke-Sqlcmd @Conn -Database master -Query "EXEC master..xp_fixeddrives;") }
  catch { return @() }
}

function Test-SqlPath {
  param(
    [Parameter(Mandatory)][object]$Conn,
    [Parameter(Mandatory)][string]$Path
  )
  $q = @"
DECLARE @p nvarchar(4000)=N'$Path';
EXEC master..xp_fileexist @p;
"@
  try { return (Invoke-Sqlcmd @Conn -Database master -Query $q | Select-Object -First 1) }
  catch { return $null }
}

function Get-XpFileExistFields {
  param([Parameter(Mandatory)]$Row)

  # xp_fileexist usually returns:
  # - File Exists
  # - File is a Directory
  # - Parent Directory Exists
  # but names can differ by client mapping; try a few variants.
  $names = $Row.PSObject.Properties.Name

  $get = {
    param([string[]]$candidates)
    foreach ($n in $candidates) { if ($names -contains $n) { return $Row.$n } }
    return $null
  }

  [pscustomobject]@{
    FileExists   = & $get @('File Exists','FileExists')
    IsDirectory  = & $get @('File is a Directory','IsDirectory','FileIsADirectory')
    ParentExists = & $get @('Parent Directory Exists','ParentDirectoryExists','ParentExists')
  }
}

# -------------------- MAIN --------------------

Import-RequiredModules

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Nie znaleziono pliku config: $ConfigPath" }
$cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if (-not $cfg.source -or -not $cfg.destination -or -not $cfg.backuppath) { throw "Config musi mieć: source, destination, backuppath." }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$logDir = $null
if ($cfg.PSObject.Properties.Name -contains 'logOptions' -and $null -ne $cfg.logOptions -and $cfg.logOptions.logDir) {
  $logDir = $cfg.logOptions.logDir
}
if (-not $logDir) { $logDir = Join-Path $scriptDir "logs" }
Ensure-Dir -Path $logDir

$alsoConsole = $true
if ($cfg.PSObject.Properties.Name -contains 'logOptions' -and $null -ne $cfg.logOptions -and $null -ne $cfg.logOptions.alsoWriteToConsole) {
  $alsoConsole = [bool]$cfg.logOptions.alsoWriteToConsole
}

$showSqlOnConsole = $true
if ($cfg.PSObject.Properties.Name -contains 'logOptions' -and $null -ne $cfg.logOptions -and $null -ne $cfg.logOptions.showSqlOnConsole) {
  $showSqlOnConsole = [bool]$cfg.logOptions.showSqlOnConsole
}

$runTs  = Get-Date -Format "yyyyMMdd_HHmmss"
$runLog = Join-Path $logDir ("run_{0}.log" -f $runTs)

Write-RunLog -LogFile $runLog -Message ("START | mode={0} | source={1} destination={2} backuppath={3}" -f ($(if($WhatIf){"WHATIF"}else{"RUN"})),$cfg.source,$cfg.destination,$cfg.backuppath) -ToConsole:($alsoConsole)

$sourceConn = New-ConnParams -ServerInstance $cfg.source -CredCfg $cfg.sourceCredential -ConnOptions $cfg.connectionOptions
$destConn   = New-ConnParams -ServerInstance $cfg.destination -CredCfg $cfg.destinationCredential -ConnOptions $cfg.connectionOptions

# Connectivity
try {
  Invoke-Sqlcmd @sourceConn -Database master -Query "SELECT 'SRC_OK' AS ok, @@SERVERNAME AS srv;" | Out-Null
  Invoke-Sqlcmd @destConn   -Database master -Query "SELECT 'DST_OK' AS ok, @@SERVERNAME AS srv;" | Out-Null
  Write-RunLog -LogFile $runLog -Message "INFO  | connectivity OK (source+destination)" -ToConsole:($alsoConsole)
} catch {
  $e = Get-ErrorDetails $_
  Write-RunLog -LogFile $runLog -Message ("ERROR | connectivity failed | {0}" -f $e.Message) -ToConsole:($alsoConsole)
  throw
}

# --- PRE-FLIGHT: log SQL Server service accounts ---
try {
  $srcSvcs = Get-ServerServices -Conn $sourceConn
  foreach ($s in $srcSvcs) {
    Write-RunLog -LogFile $runLog -Message ("SRC_SVC | {0} | {1} | {2} | account={3}" -f $s.servicename,$s.startup_type_desc,$s.status_desc,$s.service_account) -ToConsole:($alsoConsole)
  }
} catch {
  $e = Get-ErrorDetails $_
  Write-RunLog -LogFile $runLog -Message ("WARN | cannot read sys.dm_server_services on source | {0}" -f $e.Message) -ToConsole:($alsoConsole)
}

try {
  $dstSvcs = Get-ServerServices -Conn $destConn
  foreach ($s in $dstSvcs) {
    Write-RunLog -LogFile $runLog -Message ("DST_SVC | {0} | {1} | {2} | account={3}" -f $s.servicename,$s.startup_type_desc,$s.status_desc,$s.service_account) -ToConsole:($alsoConsole)
  }
} catch {
  $e = Get-ErrorDetails $_
  Write-RunLog -LogFile $runLog -Message ("WARN | cannot read sys.dm_server_services on destination | {0}" -f $e.Message) -ToConsole:($alsoConsole)
}

# --- PRE-FLIGHT: test SQL-visible access to paths (no writes; uses xp_fileexist) ---
$backupRoot = [string]$cfg.backuppath
$backupRootTrim = $backupRoot.TrimEnd('\','/')
$backupProbe = "$backupRootTrim\__sql_access_probe__.tmp"  # file won't exist; we care about ParentExists

try {
  $srcDrives = Get-SqlVisibleDrives -Conn $sourceConn
  if (@($srcDrives).Count -gt 0) {
    $letters = ($srcDrives | ForEach-Object { $_.drive } | Sort-Object) -join ","
    Write-RunLog -LogFile $runLog -Message ("SRC_PRE | xp_fixeddrives: {0}" -f $letters) -ToConsole:($alsoConsole)
  }

  $srcProbe = Test-SqlPath -Conn $sourceConn -Path $backupProbe
  if ($null -ne $srcProbe) {
    $f = Get-XpFileExistFields -Row $srcProbe
    Write-RunLog -LogFile $runLog -Message ("SRC_PRE | backuppath parentExists={0} isDir={1} fileExists={2} | probe={3}" -f $f.ParentExists,$f.IsDirectory,$f.FileExists,$backupProbe) -ToConsole:($alsoConsole)
  } else {
    Write-RunLog -LogFile $runLog -Message "SRC_PRE | xp_fileexist not available (permissions?)" -ToConsole:($alsoConsole)
  }
} catch {
  $e = Get-ErrorDetails $_
  Write-RunLog -LogFile $runLog -Message ("WARN | source preflight path test failed | {0}" -f $e.Message) -ToConsole:($alsoConsole)
}

$restoreOptions = $cfg.restoreOptions
if ($null -eq $restoreOptions) {
  $restoreOptions = [pscustomobject]@{ replace=$true; recover=$true; moveFiles=$true; dataDir="D:\SQLData"; logDir="E:\SQLLog" }
}

try {
  $dstDrives = Get-SqlVisibleDrives -Conn $destConn
  if (@($dstDrives).Count -gt 0) {
    $letters = ($dstDrives | ForEach-Object { $_.drive } | Sort-Object) -join ","
    Write-RunLog -LogFile $runLog -Message ("DST_PRE | xp_fixeddrives: {0}" -f $letters) -ToConsole:($alsoConsole)
  }

  # Destination must read the backup file too (for RESTORE)
  $dstProbe = Test-SqlPath -Conn $destConn -Path $backupProbe
  if ($null -ne $dstProbe) {
    $f = Get-XpFileExistFields -Row $dstProbe
    Write-RunLog -LogFile $runLog -Message ("DST_PRE | backuppath parentExists={0} isDir={1} fileExists={2} | probe={3}" -f $f.ParentExists,$f.IsDirectory,$f.FileExists,$backupProbe) -ToConsole:($alsoConsole)
  } else {
    Write-RunLog -LogFile $runLog -Message "DST_PRE | xp_fileexist not available (permissions?)" -ToConsole:($alsoConsole)
  }

  if ($restoreOptions.moveFiles -eq $true) {
    $dataDir = [string]$restoreOptions.dataDir
    $logDir2 = [string]$restoreOptions.logDir

    $d = Test-SqlPath -Conn $destConn -Path $dataDir
    $l = Test-SqlPath -Conn $destConn -Path $logDir2

    if ($null -ne $d) {
      $fd = Get-XpFileExistFields -Row $d
      Write-RunLog -LogFile $runLog -Message ("DST_PRE | dataDir parentExists={0} isDir={1} fileExists={2} | path={3}" -f $fd.ParentExists,$fd.IsDirectory,$fd.FileExists,$dataDir) -ToConsole:($alsoConsole)
    }
    if ($null -ne $l) {
      $fl = Get-XpFileExistFields -Row $l
      Write-RunLog -LogFile $runLog -Message ("DST_PRE | logDir  parentExists={0} isDir={1} fileExists={2} | path={3}" -f $fl.ParentExists,$fl.IsDirectory,$fl.FileExists,$logDir2) -ToConsole:($alsoConsole)
    }
  }
} catch {
  $e = Get-ErrorDetails $_
  Write-RunLog -LogFile $runLog -Message ("WARN | destination preflight path test failed | {0}" -f $e.Message) -ToConsole:($alsoConsole)
}

# DB list
$dbs = @(Get-DatabaseList -Cfg $cfg -SourceConn $sourceConn)
if (@($dbs).Count -eq 0) { throw "Brak baz do przetworzenia." }

$backupOptions = $cfg.backupOptions
if ($null -eq $backupOptions) {
  $backupOptions = [pscustomobject]@{ copyOnly=$true; compress=$true; checksum=$true; init=$true; stats=10 }
}

$throttle = 2
if ($cfg.PSObject.Properties.Name -contains 'throttleLimit' -and $null -ne $cfg.throttleLimit) {
  $throttle = [int]$cfg.throttleLimit
}

Write-RunLog -LogFile $runLog -Message ("INFO  | db_count={0} throttle={1} showSqlOnConsole={2}" -f @($dbs).Count,$throttle,$showSqlOnConsole) -ToConsole:($alsoConsole)

$jobs = @()

foreach ($db in $dbs) {
  $jobs += Start-ThreadJob -ThrottleLimit $throttle -Name "BkpRst-$db" -ArgumentList $db,$cfg,$sourceConn,$destConn,$backupOptions,$restoreOptions,$logDir,$alsoConsole,$showSqlOnConsole,$WhatIf -ScriptBlock {
    param($DbName,$Cfg,$SourceConn,$DestConn,$BackupOptions,$RestoreOptions,$LogDir,$AlsoConsole,$ShowSqlOnConsole,$WhatIfMode)

    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
    Import-Module SqlServer -ErrorAction Stop

    function Write-DbLog {
      param([string]$File,[string]$Msg,[switch]$ToConsole)
      $line = "{0} | {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $Msg
      Add-Content -LiteralPath $File -Value $line -Encoding UTF8
      if ($ToConsole) { Write-Host $line }
    }

    function Log-SqlCommand {
      param(
        [Parameter(Mandatory)][string]$DbLog,
        [Parameter(Mandatory)][string]$Tag,
        [Parameter(Mandatory)][string]$SqlText,
        [switch]$ToConsole
      )
      $len = if ($null -ne $SqlText) { $SqlText.Length } else { 0 }
      Write-DbLog -File $DbLog -Msg ("SQL   | {0} COMMAND BEGIN (len={1})" -f $Tag,$len) -ToConsole:$ToConsole
      if ([string]::IsNullOrWhiteSpace($SqlText)) {
        Write-DbLog -File $DbLog -Msg "SQL   | <EMPTY>" -ToConsole:$ToConsole
      } else {
        $norm = $SqlText -replace "`r`n","`n" -replace "`r","`n"
        foreach ($ln in ($norm -split "`n")) {
          Write-DbLog -File $DbLog -Msg ("SQL   | {0}" -f $ln) -ToConsole:$ToConsole
        }
      }
      Write-DbLog -File $DbLog -Msg ("SQL   | {0} COMMAND END" -f $Tag) -ToConsole:$ToConsole
    }

    function Get-Err {
      param($Err)
      $inv = $Err.InvocationInfo
      $ex  = $Err.Exception
      $lineText = $null; $lineNo = $null; $script = $null
      if ($null -ne $inv) { $lineText = $inv.Line; $lineNo = $inv.ScriptLineNumber; $script = $inv.ScriptName }
      $stack = $null
      if ($null -ne $ex -and $ex.StackTrace) { $stack = ($ex.StackTrace -split "`r?`n" | Select-Object -First 15) -join " | " }
      [pscustomobject]@{
        Message = if ($null -ne $ex) { $ex.Message } else { $Err.ToString() }
        Type    = if ($null -ne $ex) { $ex.GetType().FullName } else { $null }
        Script  = $script
        LineNo  = $lineNo
        Line    = $lineText
        Stack   = $stack
      }
    }

    function Log-ServiceAccounts {
      param([string]$DbLog,[object]$Conn,[string]$Tag,[switch]$ToConsole)
      try {
        $rows = @(Invoke-Sqlcmd @Conn -Database master -Query "SELECT servicename, status_desc, service_account FROM sys.dm_server_services ORDER BY servicename;")
        foreach ($r in $rows) {
          Write-DbLog -File $DbLog -Msg ("{0}_SVC | {1} | {2} | account={3}" -f $Tag,$r.servicename,$r.status_desc,$r.service_account) -ToConsole:$ToConsole
        }
      } catch {
        $e = Get-Err $_
        Write-DbLog -File $DbLog -Msg ("{0}_SVC | WARN | {1}" -f $Tag,$e.Message) -ToConsole:$ToConsole
      }
    }

    function Dump-RestoreHeaderOnlyToLog {
      param([string]$BackupFile,$Conn,[string]$DbLog,[switch]$ToConsole)
      Write-DbLog -File $DbLog -Msg "INFO  | RESTORE HEADERONLY begin" -ToConsole:$ToConsole
      $q = "RESTORE HEADERONLY FROM DISK = N'$BackupFile';"
      Log-SqlCommand -DbLog $DbLog -Tag "HEADERONLY" -SqlText $q -ToConsole:$ToConsole
      $hdr = @(Invoke-Sqlcmd @Conn -Database master -Query $q)
      if (@($hdr).Count -eq 0) { Write-DbLog -File $DbLog -Msg "INFO  | RESTORE HEADERONLY returned 0 rows" -ToConsole:$ToConsole; return }
      $pick = $hdr | Select-Object -First 1 | Select-Object BackupTypeDescription, Compressed, Position, DatabaseName, BackupStartDate, BackupFinishDate, RecoveryModel, HasBackupChecksums, IsCopyOnly, ServerName, MachineName, InstanceName
      Write-DbLog -File $DbLog -Msg "INFO  | RESTORE HEADERONLY (selected fields):" -ToConsole:$ToConsole
      foreach ($p in $pick.PSObject.Properties) { Write-DbLog -File $DbLog -Msg ("HDR   | {0}={1}" -f $p.Name,$p.Value) -ToConsole:$ToConsole }
      Write-DbLog -File $DbLog -Msg "INFO  | RESTORE HEADERONLY end" -ToConsole:$ToConsole
    }

    $safeDb = $DbName.Replace("[","").Replace("]","")
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $dbLog = Join-Path $LogDir ("{0}_{1}.log" -f $safeDb,$ts)

    # IMPORTANT: backup file path is for SQL Server, not for local PowerShell
    $backupRootTrim = ([string]$Cfg.backuppath).TrimEnd('\','/')
    $backupFile = "$backupRootTrim\{0}_{1}.bak" -f $safeDb,$ts

    $result = [ordered]@{
      Database     = $DbName
      BackupFile   = $backupFile
      DbLog        = $dbLog
      Started      = (Get-Date)
      BackupOk     = $false
      RestoreOk    = $false
      WhatIf       = [bool]$WhatIfMode
      Error        = $null
      ErrorType    = $null
      ErrorAt      = $null
      ErrorLine    = $null
      ErrorStack   = $null
      DurationSec  = $null
      Finished     = $null
    }

    Write-DbLog -File $dbLog -Msg ("START | mode={0} | db={1} backupFile={2}" -f ($(if($WhatIfMode){"WHATIF"}else{"RUN"})),$DbName,$backupFile) -ToConsole:($AlsoConsole)

    # Per-DB: log service accounts too (useful in DB log)
    Log-ServiceAccounts -DbLog $dbLog -Conn $SourceConn -Tag "SRC" -ToConsole:($AlsoConsole)
    Log-ServiceAccounts -DbLog $dbLog -Conn $DestConn   -Tag "DST" -ToConsole:($AlsoConsole)

    try {
      # Build BACKUP command (always)
      $copyOnly  = if ($BackupOptions.copyOnly  -eq $true) { "COPY_ONLY," } else { "" }
      $compress  = if ($BackupOptions.compress  -eq $true) { "COMPRESSION," } else { "NO_COMPRESSION," }
      $checksum  = if ($BackupOptions.checksum  -eq $true) { "CHECKSUM," } else { "NO_CHECKSUM," }
      $init      = if ($BackupOptions.init      -eq $true) { "INIT," } else { "NOINIT," }
      $stats     = if ($BackupOptions.stats) { "STATS = $($BackupOptions.stats)," } else { "" }

      $with = @($copyOnly,$compress,$checksum,$init,$stats) -join " "
      $with = $with.Trim()
      if ($with.EndsWith(",")) { $with = $with.TrimEnd(",") }

      $qBackup = @"
BACKUP DATABASE [$DbName]
TO DISK = N'$backupFile'
WITH $with;
"@

      # Log intended BACKUP always
      Log-SqlCommand -DbLog $dbLog -Tag "BACKUP" -SqlText $qBackup -ToConsole:($ShowSqlOnConsole -and $AlsoConsole)

      if ($WhatIfMode) {
        Write-DbLog -File $dbLog -Msg "WHATIF| BACKUP skipped" -ToConsole:($AlsoConsole)
      } else {
        Write-DbLog -File $dbLog -Msg "STEP  | BACKUP begin" -ToConsole:($AlsoConsole)
        Invoke-Sqlcmd @SourceConn -Database master -Query $qBackup | Out-Null
        $result.BackupOk = $true
        Write-DbLog -File $dbLog -Msg "STEP  | BACKUP ok" -ToConsole:($AlsoConsole)
      }

      # Build RESTORE command (always). If moveFiles=true we need filelist (requires backup to exist).
      $replace = if ($RestoreOptions.replace -eq $true) { "REPLACE," } else { "" }
      $recover = if ($RestoreOptions.recover -eq $true) { "RECOVERY," } else { "NORECOVERY," }

      $moveClause = ""
      if ($RestoreOptions.moveFiles -eq $true) {

        $dataDir = [string]$RestoreOptions.dataDir
        $logDir2 = [string]$RestoreOptions.logDir
        if (-not $dataDir -or -not $logDir2) { throw "restoreOptions.moveFiles=true wymaga dataDir i logDir." }

        $qFileList = "RESTORE FILELISTONLY FROM DISK = N'$backupFile';"
        Log-SqlCommand -DbLog $dbLog -Tag "FILELISTONLY" -SqlText $qFileList -ToConsole:($ShowSqlOnConsole -and $AlsoConsole)

        if ($WhatIfMode) {
          Write-DbLog -File $dbLog -Msg "WHATIF| FILELISTONLY skipped (needs actual backup file)" -ToConsole:($AlsoConsole)
          Write-DbLog -File $dbLog -Msg ("WHATIF| MOVE targets planned: dataDir={0} logDir={1} (will be resolved after FILELISTONLY)" -f $dataDir,$logDir2) -ToConsole:($AlsoConsole)
        } else {
          $files = @(Invoke-Sqlcmd @DestConn -Database master -Query $qFileList)

          $moves = New-Object System.Collections.Generic.List[string]
          foreach ($f in @($files)) {
            $logical = $f.LogicalName
            $type    = $f.Type
            $base    = [System.IO.Path]::GetFileName($f.PhysicalName)

            $targetDir = if ($type -eq "L") { $logDir2 } else { $dataDir }

            # IMPORTANT: build as string (no Join-Path)
            $targetDirTrim = $targetDir.TrimEnd('\','/')
            $target = "$targetDirTrim\$base"

            Write-DbLog -File $dbLog -Msg ("MOVE  | {0} ({1}) -> {2}" -f $logical,$type,$target) -ToConsole:($AlsoConsole)
            $moves.Add("MOVE N'$logical' TO N'$target'")
          }

          if ($moves.Count -gt 0) { $moveClause = ($moves -join ",`n    ") + "," }
        }
      }

      $withParts = @($replace,$recover,$moveClause) -join "`n    "
      $withParts = $withParts.Trim()
      if ($withParts.EndsWith(",")) { $withParts = $withParts.TrimEnd(",") }

      $qRestore = @"
RESTORE DATABASE [$DbName]
FROM DISK = N'$backupFile'
WITH
    $withParts;
"@

      # Log intended RESTORE always
      Log-SqlCommand -DbLog $dbLog -Tag "RESTORE" -SqlText $qRestore -ToConsole:($ShowSqlOnConsole -and $AlsoConsole)

      if ($WhatIfMode) {
        Write-DbLog -File $dbLog -Msg "WHATIF| RESTORE skipped" -ToConsole:($AlsoConsole)
      } else {
        # Helpful: HEADERONLY before restore (now the file exists)
        Dump-RestoreHeaderOnlyToLog -BackupFile $backupFile -Conn $DestConn -DbLog $dbLog -ToConsole:($AlsoConsole)

        Write-DbLog -File $dbLog -Msg "STEP  | RESTORE begin" -ToConsole:($AlsoConsole)
        Invoke-Sqlcmd @DestConn -Database master -Query $qRestore | Out-Null
        $result.RestoreOk = $true
        Write-DbLog -File $dbLog -Msg "STEP  | RESTORE ok" -ToConsole:($AlsoConsole)
        Write-DbLog -File $dbLog -Msg "DONE  | success" -ToConsole:($AlsoConsole)
      }
    }
    catch {
      $e = Get-Err $_
      $result.Error      = $e.Message
      $result.ErrorType  = $e.Type
      $result.ErrorAt    = if ($e.Script -and $e.LineNo) { "{0}:{1}" -f $e.Script,$e.LineNo } else { $null }
      $result.ErrorLine  = $e.Line
      $result.ErrorStack = $e.Stack

      Write-DbLog -File $dbLog -Msg ("ERROR | {0}" -f $result.Error) -ToConsole:($AlsoConsole)
      if ($result.ErrorAt)    { Write-DbLog -File $dbLog -Msg ("ERROR | AT    | {0}" -f $result.ErrorAt) -ToConsole:($AlsoConsole) }
      if ($result.ErrorLine)  { Write-DbLog -File $dbLog -Msg ("ERROR | LINE  | {0}" -f $result.ErrorLine) -ToConsole:($AlsoConsole) }
      if ($result.ErrorType)  { Write-DbLog -File $dbLog -Msg ("ERROR | TYPE  | {0}" -f $result.ErrorType) -ToConsole:($AlsoConsole) }
      if ($result.ErrorStack) { Write-DbLog -File $dbLog -Msg ("ERROR | STACK | {0}" -f $result.ErrorStack) -ToConsole:($AlsoConsole) }
    }
    finally {
      $result.Finished = (Get-Date)
      $result.DurationSec = [math]::Round((New-TimeSpan -Start $result.Started -End $result.Finished).TotalSeconds,2)
      Write-DbLog -File $dbLog -Msg ("END   | durationSec={0}" -f $result.DurationSec) -ToConsole:($AlsoConsole)
    }

    [pscustomobject]$result
  }
}

$results = @(Receive-Job -Job $jobs -Wait -AutoRemoveJob)

foreach ($r in ($results | Sort-Object Database)) {
  $status = if ($r.WhatIf) { "WHATIF" } elseif ($r.BackupOk -and $r.RestoreOk) { "OK" } else { "FAIL" }
  Write-RunLog -LogFile $runLog -Message ("RESULT| {0} | whatIf={1} backup={2} restore={3} dur={4}s | dbLog={5} | {6}" -f $r.Database,$r.WhatIf,$r.BackupOk,$r.RestoreOk,$r.DurationSec,$r.DbLog,$status) -ToConsole:($alsoConsole)
  if ($r.Error) { Write-RunLog -LogFile $runLog -Message ("ERROR | {0} | {1}" -f $r.Database,$r.Error) -ToConsole:($alsoConsole) }
}

$results | Sort-Object Database | Format-Table -AutoSize

if (-not $WhatIf) {
  $failed = @($results | Where-Object { -not $_.BackupOk -or -not $_.RestoreOk })
  if (@($failed).Count -gt 0) {
    Write-RunLog -LogFile $runLog -Message ("END   | FAILED | dbs={0}" -f (($failed.Database) -join ", ")) -ToConsole:($alsoConsole)
    Write-Error ("Niektóre bazy poległy: {0}" -f (($failed.Database) -join ", "))
    exit 2
  }

  Write-RunLog -LogFile $runLog -Message "END   | SUCCESS | wszystkie bazy OK" -ToConsole:($alsoConsole)
  Write-Host "`nOK: wszystkie bazy zbackupowane i odtworzone."
} else {
  Write-RunLog -LogFile $runLog -Message "END   | WHATIF | nic nie wykonano (tylko preflight + log komend)" -ToConsole:($alsoConsole)
  Write-Host "`nWHATIF: nic nie wykonano (tylko preflight + log komend)."
}

Write-Host "Run log: $runLog"