# Runbook: Blocking Emergency Mitigation

## Cel

Szybkie ograniczenie wpływu blocking incident bez utraty evidence i bez pochopnego KILL.

## Kiedy użyć
- wiele sesji czeka na LCK_M_*
- aplikacja timeoutuje
- head blocker blokuje krytyczny workload

## Struktura
- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth
- [Blocking troubleshooting](../../troubleshooting/blocking/)
- [DBA Daily Pack](../../tools/DBADaillyPack/sql/07_Blocking_And_LongRunning.sql)
- [Blocking Snapshot](../../scripts/t-sql/Reques_PerfPack/03_Blocking_Snapshot.sql)

> Blocking jest objawem; KILL może być mitigacją awaryjną, ale najpierw zapisz blocker, transakcję, SQL i business context.
