# Standard: Backup & Recovery

## Purpose

Zapewnić, że każda baza objęta standardem może zostać odtworzona do wymaganego punktu i w czasie zgodnym z RPO/RTO.

## Scope

- bazy produkcyjne,
- bazy krytyczne testowe/DR, jeżeli mają zdefiniowane RPO/RTO,
- bazy systemowe `master`, `msdb`, `model`.

## Requirements

### Required

- Każda baza ma zdefiniowany recovery model zgodny z wymaganym RPO/RTO.
- Bazy w modelu FULL mają regularne backupy logu.
- Backupy FULL/DIFF/LOG są monitorowane.
- Backupy są przechowywane poza wolumenem danych.
- Backupy produkcyjne są szyfrowane zgodnie z polityką bezpieczeństwa.
- `RESTORE VERIFYONLY` jest używany jako kontrola media, ale nie zastępuje test restore.
- Regularny test restore potwierdza recoverability.
- Po restore wykonywany jest `DBCC CHECKDB`.
- Backupy baz systemowych są częścią planu DR.
- Klucze/certyfikaty potrzebne do restore zaszyfrowanych backupów są backupowane osobno.

### Recommended

- FULL co najmniej raz dziennie.
- DIFF zgodnie z RPO i wielkością bazy.
- LOG zgodnie z RPO; dla typowego OLTP repo używa przykładu 15 min.
- Kompresja backupów jako ustawienie domyślne, jeśli środowisko nie ma przeciwwskazań.
- Test restore co najmniej okresowo i po istotnych zmianach infrastruktury.
- Dla VLDB rozważyć striping, filegroup backups i piecemeal restore.

### Not allowed

- Traktowanie zielonego statusu joba jako dowodu recoverability.
- Cykliczne przełączanie FULL/SIMPLE bez uzasadnienia.
- Backup na jedyną kopię na tym samym wolumenie co dane.
- Używanie `COPY_ONLY` jako części zwykłej strategii bez świadomego celu.
- Brak testów restore dla baz krytycznych.

## Default configuration

Dla typowego OLTP w FULL:

```text
FULL  : 1x / dobę
DIFF  : według RPO / wielkości
LOG   : co 15 min jako punkt wyjścia
VERIFY: automatyczna kontrola
TEST RESTORE: regularnie
```

Wartości muszą zostać dopasowane do konkretnego RPO/RTO.

## Exceptions

Wyjątek musi zawierać:

- bazę/system,
- właściciela,
- uzasadnienie,
- zaakceptowane RPO/RTO,
- okres ważności wyjątku,
- plan kompensacyjny.

## Validation

- historia w `msdb.dbo.backupset`,
- brak przerw w wymaganym log chain,
- wyniki testów restore,
- wynik `DBCC CHECKDB`,
- porównanie realnego restore duration z RTO.

## Ownership

DBA / właściciel platformy SQL Server.

## Review cycle

- co najmniej raz na kwartał,
- po zmianie RPO/RTO,
- po migracji,
- po zmianie storage/backup platformy,
- po incydencie recovery.

## References

- [Backup Strategy](../../docs/Inside_SQL_Server2022_Databases/Backup_Strategy.md)
- [Backup/Restore Troubleshooting](../../troubleshooting/backup-restore/)
- [Backup/Restore/Recovery Runbook](../../runbooks/backup-restore-recovery/)
