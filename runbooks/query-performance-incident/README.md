# Runbook: Query Performance Incident

## Cel

Przywrócenie wydajności konkretnego zapytania przez analizę historii, planu, waits i workloadu zamiast pojedynczego 'kosztu planu'.

## Kiedy użyć
- pojedyncze zapytanie lub endpoint zwalnia
- timeouty
- wzrost CPU/reads/duration

## Struktura
- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth
- [Query Performance troubleshooting](../../troubleshooting/query-performance/)
- [Request PerfPack](../../scripts/t-sql/Reques_PerfPack/)
- [Query Store runbook](../query-store-regression-mitigation/)

> Najpierw ustal, czy problem jest historyczną regresją planu, blockingiem, resource waitem czy zmianą workloadu.
