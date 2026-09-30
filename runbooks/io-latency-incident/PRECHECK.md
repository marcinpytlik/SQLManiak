# I/O Latency Incident — PRECHECK

1. Zdefiniuj problem window.
2. Zbierz per-file read/write latency.
3. Zbierz PAGEIOLATCH/WRITELOG delta.
4. Sprawdź workload reads/writes i top queries.
5. Sprawdź backup/CHECKDB/autogrowth w tym samym oknie.

## Evidence before
- file latency
- I/O bytes/ops
- wait deltas
- top queries/plans
- storage events

## Stop conditions
- diagnoza opiera się tylko na wait name
- brak rozdzielenia data/log/TempDB
- planowana zmiana storage bez evidence
