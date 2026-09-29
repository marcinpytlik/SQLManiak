# Runbook: TempDB Emergency

## Cel

Opanowanie krytycznego wzrostu, braku miejsca lub contention TempDB bez pochopnego shrink/restart.

## Kiedy użyć
- TempDB near/full
- version store rośnie
- workspace spills dominują
- allocation contention
- problem po FCI failover

## Struktura
- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth
- [TempDB troubleshooting](../../troubleshooting/tempdb/)
- [DBA Daily Pack TempDB](../../tools/DBADaillyPack/sql/03_Tempdb_Health.sql)
- [TempDB Control](../../docs/Inside_SQL_Server2022/Tempdb_Control/)

> Najpierw ustal konsumenta i typ problemu; restart lub shrink usuwa symptom i może zniszczyć evidence.
