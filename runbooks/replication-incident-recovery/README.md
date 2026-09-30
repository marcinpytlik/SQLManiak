# Runbook: Transactional Replication Incident Recovery

## Cel

Przywrócenie przepływu transactional replication po błędzie agentów lub backlogu bez pochopnej reinicjalizacji.

## Kiedy użyć

- Log Reader/Distribution Agent failed
- backlog rośnie
- subscriber nie nadąża

## Struktura
- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth
- [Replication diagnostics](../../scripts/SQLManiak-Replication-Diagnostics/README.md)
- [Replication troubleshooting](../../troubleshooting/replication/)

> Reinitializacja to ciężkie narzędzie; najpierw ustal job, connectivity, distribution, schema/data i performance.
