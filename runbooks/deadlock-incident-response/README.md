# Runbook: Deadlock Incident Response

## Cel

Zebranie deadlock graph, rekonstrukcja cyklu i wdrożenie kontrolowanej mitigacji bez maskowania problemu samym retry.

## Kiedy użyć
- error 1205
- alert deadlock
- wzrost deadlocks/sec

## Struktura
- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth
- [Deadlocks troubleshooting](../../troubleshooting/deadlocks/)
- [investigate.sql](../../scripts/t-sql/investigate.sql)
- [SqlStressLab](../../tools/SqlStressLab/)

> Ofiara deadlocka nie musi być winowajcą; analizuj cały graph i kolejność dostępu do zasobów.
