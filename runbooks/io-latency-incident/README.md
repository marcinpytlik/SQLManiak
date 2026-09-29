# Runbook: I/O Latency Incident

## Cel

Rozpoznanie, czy problem I/O wynika z rzeczywistej latencji storage, nadmiernego workloadu czy regresji planu.

## Kiedy użyć
- PAGEIOLATCH/WRITELOG rośnie
- latencja plików rośnie
- backup/restore lub zapytania zwalniają

## Struktura
- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth
- [I/O troubleshooting](../../troubleshooting/io/)
- [Wait Statistics](../../troubleshooting/wait-statistics/)
- [Query Performance](../../troubleshooting/query-performance/)

> PAGEIOLATCH nie oznacza automatycznie wolnego storage; porównaj latency z ilością pracy i access path.
