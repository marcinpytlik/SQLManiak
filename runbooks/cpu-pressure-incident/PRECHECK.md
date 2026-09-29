# CPU Pressure Incident — PRECHECK

1. Sprawdź host CPU i SQL process CPU.
2. Sprawdź VISIBLE ONLINE schedulers.
3. Sprawdź runnable_tasks_per_active_scheduler.
4. Zbierz SOS_SCHEDULER_YIELD i signal wait delta.
5. Znajdź top CPU active/history queries.

## Evidence before
- host/sql/other CPU
- scheduler counts
- runnable queue
- top query CPU
- throughput/latency

## Stop conditions
- diagnoza opiera się tylko na jednym CPU %
- planowana jest zmiana MAXDOP bez identyfikacji workloadu
- brak porównywalnego baseline
