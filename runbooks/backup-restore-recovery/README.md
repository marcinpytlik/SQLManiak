# Runbook: Backup / Restore / Recovery

## Cel

Powtarzalna procedura odtworzenia bazy SQL Server z dostępnego łańcucha backupów oraz potwierdzenia, że osiągnięto wymagany punkt odzyskania i akceptowalny czas odtworzenia.

Ten runbook opiera się na istniejących materiałach repo:

- [Backup Strategy](../../docs/Inside_SQL_Server2022_Databases/Backup_Strategy.md)
- [Backup Overview](../../docs/Inside_SQL_Server2022_Databases/Backup_Overview.md)
- [Automated Restore Test](../../docs/RestoreTest/PowerShell/Restore_AutomatedTest.ps1)
- [VLDB Backup/Restore Checklist](../../docs/VLDB_Survival_Kit_SQLServer_2022/CHECKLISTS/02_Backup_Restore_VLDB.md)
- [Estimate Restore Space](../../scripts/t-sql/backup/restoresize.sql)

## Zakres

Runbook obejmuje:

- identyfikację recovery model,
- wybór FULL / DIFF / LOG,
- point-in-time recovery przez `STOPAT`,
- kontrolę miejsca i layoutu plików,
- restore z `NORECOVERY` / `RECOVERY`,
- walidację przez stan bazy i `DBCC CHECKDB`,
- pomiar czasu restore względem RTO.

## Struktura

- [PRECHECK.md](PRECHECK.md) — warunki wejściowe i kompletność chaina.
- [RUNBOOK.md](RUNBOOK.md) — procedura wykonawcza.
- [VALIDATION.md](VALIDATION.md) — potwierdzenie recoverability.
- [ROLLBACK.md](ROLLBACK.md) — bezpieczne wycofanie/test i warunki eskalacji.

## Zasada

> Zielony backup job nie potwierdza recoverability. Potwierdza ją dopiero poprawny restore do wymaganego punktu, walidacja bazy i pomiar RTO.
