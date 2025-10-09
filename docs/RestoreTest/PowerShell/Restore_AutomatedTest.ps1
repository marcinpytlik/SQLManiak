param(
    [string]$ServerInstance = "localhost",
    [string]$DbName         = "DemoDB_Test",
    [string]$DataPath       = "D:\SQLData",
    [string]$LogPath        = "D:\SQLLog",
    [string]$BackupFull     = "D:\Backup\DemoDB_FULL.bak",
    [string]$BackupDiff     = "D:\Backup\DemoDB_DIFF.bak",
    [string[]]$BackupLogs   = @("D:\Backup\DemoDB_LOG_1.trn","D:\Backup\DemoDB_LOG_2.trn"),
    [string]$ReportCsv      = "D:\Backup\Restore_Test_Log.csv",
    [switch]$PointInTime,
    [string]$StopAt         = "2025-10-08T08:15:00"
)

$start = Get-Date
$steps = @()

function Run-Tsql($q){
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $q -QueryTimeout 0
}

# Krok 1: Restore FULL
$steps += "RESTORE FULL"
Run-Tsql @"
RESTORE DATABASE [$DbName]
FROM DISK = N'$BackupFull'
WITH MOVE N'DemoDB'     TO N'$DataPath\$DbName.mdf',
     MOVE N'DemoDB_log' TO N'$LogPath\$DbName.ldf',
     REPLACE, NORECOVERY;
"@

# Krok 2: Restore DIFF (jeśli istnieje plik)
if (Test-Path $BackupDiff) { 
    $steps += "RESTORE DIFF"
    Run-Tsql "RESTORE DATABASE [$DbName] FROM DISK = N'$BackupDiff' WITH NORECOVERY;"
}

# Krok 3: Restore LOGi (lub STOPAT)
if ($PointInTime) {
    $steps += "RESTORE LOG (STOPAT=$StopAt)"
    # Zakładamy, że $BackupLogs zawiera co najmniej jeden plik z odpowiednim czasem
    for ($i=0; $i -lt $BackupLogs.Count; $i++) {
        $log = $BackupLogs[$i]
        $last = ($i -eq $BackupLogs.Count - 1)
        if ($last) {
            Run-Tsql "RESTORE LOG [$DbName] FROM DISK = N'$log' WITH STOPAT = N'$StopAt', RECOVERY;"
        } else {
            Run-Tsql "RESTORE LOG [$DbName] FROM DISK = N'$log' WITH NORECOVERY;"
        }
    }
} else {
    $steps += "RESTORE LOG chain"
    for ($i=0; $i -lt $BackupLogs.Count; $i++) {
        $log = $BackupLogs[$i]
        $last = ($i -eq $BackupLogs.Count - 1)
        if ($last) {
            Run-Tsql "RESTORE LOG [$DbName] FROM DISK = N'$log' WITH RECOVERY;"
        } else {
            Run-Tsql "RESTORE LOG [$DbName] FROM DISK = N'$log' WITH NORECOVERY;"
        }
    }
}

# Krok 4: Weryfikacja
$steps += "DBCC CHECKDB + status"
Run-Tsql @"
DBCC CHECKDB([$DbName]) WITH NO_INFOMSGS;
SELECT name, state_desc, recovery_model_desc FROM sys.databases WHERE name = N'$DbName';
"@

$end = Get-Date
$durationMin = [math]::Round(($end - $start).TotalMinutes,2)

# Raport CSV (append-friendly)
$line = ('{0},{1},{2},"{3}"' -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $DbName, $durationMin, ($steps -join ' -> '))
$header = "timestamp,dbname,duration_min,steps"
if (!(Test-Path $ReportCsv)) { $header | Out-File -FilePath $ReportCsv -Encoding UTF8 }
$line | Out-File -FilePath $ReportCsv -Append -Encoding UTF8

Write-Host "Zakończono. Czas trwania (min): $durationMin"


# --- Metrics: insert into msdb.dbo.RestorePerfLog via helper proc ---
# Approximate size stats: read_mb from FULL backup size, write_mb estimated as data+log target sizes isn't trivial;
# we log the full backup compressed size as read_mb proxy.
try {
    $readMb = 0
    $backupFullPath = $BackupFull
    if (Test-Path $backupFullPath) {
        # Query msdb for last FULL backup of source DB (DemoDB) to get compressed size as a proxy for read volume
        $q = @"
SELECT TOP(1) CAST(bs.compressed_backup_size/1024.0/1024 AS DECIMAL(18,2)) AS read_mb
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bm ON bs.media_set_id = bm.media_set_id
WHERE bs.type = 'D' AND bs.database_name = 'DemoDB'
ORDER BY bs.backup_finish_date DESC;
"@
        $res = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $q
        if ($res -and $res.read_mb) { $readMb = [decimal]$res.read_mb }
    }

    $cpuSec = 0  # Not trivial to fetch per-restore; leave as 0 or extend later with perf counters
    $restoreType = if ($PointInTime) { "FULL+DIFF+LOG(StopAt)" } else { "FULL+DIFF+LOG" }
    $notes = "Automated restore test via Restore_AutomatedTest.ps1"
    $call = @"
EXEC msdb.dbo.usp_RestorePerfLog_Upsert
    @database_name = N'$DbName',
    @restore_type  = N'$restoreType',
    @duration_min  = $durationMin,
    @read_mb       = $readMb,
    @write_mb      = NULL,
    @cpu_sec       = $cpuSec,
    @source_db     = N'DemoDB',
    @notes         = N'$notes';
"@
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $call -QueryTimeout 0
    Write-Host "Perf metrics logged to msdb.dbo.RestorePerfLog"
} catch {
    Write-Warning "Failed to log perf metrics: $_"
}
