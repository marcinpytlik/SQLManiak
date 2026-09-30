# Runbook: Memory Pressure Incident

## Cel

Rozpoznanie wewnętrznej lub zewnętrznej presji pamięci oraz ograniczenie wpływu na workload bez reakcji na pojedynczy licznik.

## Kiedy użyć
- Memory Grants Pending > 0
- RESOURCE_SEMAPHORE
- PLE spada względem baseline
- lazy writes/OS pressure rosną

## Struktura
- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth
- [Memory troubleshooting](../../troubleshooting/memory/)
- [Memory Internals](../../docs/MemoryInternals/)
- [Wait Statistics](../../troubleshooting/wait-statistics/)

> PLE ani jedna metryka nie są root cause; koreluj grants, clerks, OS pressure, workload i konfigurację.
