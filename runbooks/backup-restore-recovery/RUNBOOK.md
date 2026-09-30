# Backup / Restore / Recovery — RUNBOOK

## 1. Zapisz czas rozpoczęcia

Potrzebujesz go do pomiaru RTO.

## 2. Przywróć FULL

Wzorzec:

```sql
RESTORE DATABASE [TargetDb]
FROM DISK = N'<FULL_BACKUP>'
WITH
    MOVE N'<DataLogicalName>' TO N'<TargetDataPath>',
    MOVE N'<LogLogicalName>'  TO N'<TargetLogPath>',
    NORECOVERY,
    STATS = 10;
```

Jeżeli jest więcej plików danych/logów, przygotuj kompletne mapowanie z `RESTORE FILELISTONLY`.

## 3. Przywróć DIFF — jeżeli jest częścią planu

```sql
RESTORE DATABASE [TargetDb]
FROM DISK = N'<DIFF_BACKUP>'
WITH NORECOVERY,
     STATS = 10;
```

## 4. Przywróć LOG chain

Dla wszystkich logów oprócz ostatniego:

```sql
RESTORE LOG [TargetDb]
FROM DISK = N'<LOG_BACKUP>'
WITH NORECOVERY,
     STATS = 10;
```

### Point-in-time

Na właściwym backupie logu zastosuj:

```sql
RESTORE LOG [TargetDb]
FROM DISK = N'<LOG_BACKUP>'
WITH STOPAT = N'<YYYY-MM-DDTHH:MM:SS>',
     RECOVERY,
     STATS = 10;
```

### Restore do końca chaina

Ostatni log:

```sql
RESTORE LOG [TargetDb]
FROM DISK = N'<LAST_LOG_BACKUP>'
WITH RECOVERY,
     STATS = 10;
```

## 5. Jeżeli nie ma kolejnych backupów

Zakończ recovery:

```sql
RESTORE DATABASE [TargetDb] WITH RECOVERY;
```

Wykonuj ten krok dopiero wtedy, gdy masz pewność, że nie musisz już dokładać kolejnych DIFF/LOG.

## 6. Wariant automatyczny

Repo zawiera:

- [Restore_AutomatedTest.ps1](../../docs/RestoreTest/PowerShell/Restore_AutomatedTest.ps1)

Skrypt realizuje sekwencję:

```text
FULL
→ DIFF
→ LOG chain / STOPAT
→ RECOVERY
→ DBCC CHECKDB
→ status
→ duration report
```

Używaj go po ustawieniu poprawnych parametrów dla konkretnego środowiska.

## 7. Przejdź do walidacji

Po `RECOVERY` wykonaj kroki z [VALIDATION.md](VALIDATION.md).
