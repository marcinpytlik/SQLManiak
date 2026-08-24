# BACKUP collector

`Collect-BackupHistory.ps1` czyta `msdb.dbo.backupset` i `msdb.dbo.backupmediafamily`
dla aktywnych instancji z `dbo.Instance`.

Domyślnie:
- repo: `localhost / DBACentralRepository`
- historia: 35 dni
- instancje: `IsEnabled = 1 AND IsReachable = 1`
- ScanType: `BACKUP`

Uruchomienie:

```powershell
.\Collect-BackupHistory.ps1
```

Po teście:

```sql
SELECT TOP (20) * FROM backup.BackupHistory ORDER BY BackupFinishDate DESC;
SELECT TOP (20) * FROM backup.BackupFile ORDER BY BackupFileId DESC;
SELECT TOP (20) * FROM dbo.ScanRun WHERE ScanType='BACKUP' ORDER BY ScanRunId DESC;
SELECT TOP (20) * FROM report.vGrafanaBackupStatus ORDER BY ServerInstance, DatabaseName;
```

Rejestracja w Collector Health:

```text
29_Register_Backup_Collector.sql
```

Polityka:
- expected: 15 min
- warning: 30 min
- critical: 60 min
