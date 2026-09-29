# Runbook: DBCC CHECKDB / Corruption Recovery

## Cel

Bezpieczna reakcja na błędy integralności z preferencją odzyskania danych z poprawnego backupu.

## Kiedy użyć

- DBCC CHECKDB wykrywa corruption
- błędy 823/824/825
- suspect_pages wskazuje uszkodzenia

## Struktura
- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth
- [DBCC commands](../../docs/Inside_SQL_Server2022/97_SQLServer2022_DBCC_Commands.md)
- [Page Restore demo](../../docs/PageRestore.sql)
- [Backup/Restore runbook](../backup-restore-recovery/)

> Najpierw zachowaj evidence i zakres uszkodzenia; repair z możliwą utratą danych nie zastępuje restore.
