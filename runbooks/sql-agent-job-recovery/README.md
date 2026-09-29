# Runbook: SQL Agent Job Recovery

## Cel

Przywrócenie poprawnego wykonania joba SQL Agent oraz walidacja jego rzeczywistego rezultatu.

## Kiedy użyć

- job Failed/Retry/Canceled
- job nie wystartował
- job jest long-running

## Struktura
- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth
- [SQL Agent troubleshooting](../../troubleshooting/sql-agent/)
- [DBA Daily Pack](../../tools/DBADaillyPack/sql/02_Agent_Jobs_Health.sql)
- [investigate.sql](../../scripts/t-sql/investigate.sql)

> Status Succeeded nie wystarcza — potwierdź rzeczywisty artifact/output.
