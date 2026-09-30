# Runbook: CPU Pressure Incident

## Cel

Rozpoznanie rzeczywistej presji CPU SQL Server i wskazanie workloadu odpowiedzialnego za scheduler pressure.

## Kiedy użyć
- wysoki CPU
- runnable queue rośnie
- SOS_SCHEDULER_YIELD/signal waits rosną
- latency aplikacji rośnie

## Struktura
- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth
- [CPU troubleshooting](../../troubleshooting/cpu/)
- [CPU health collector](../../scripts/zabbix-mssql-monitoring/custom-queries/sqlmaniak_cpu_health.sql)
- [Request PerfPack](../../scripts/t-sql/Reques_PerfPack/)

> CPU > X% nie jest diagnozą; potwierdź SQL process CPU, liczbę VISIBLE ONLINE schedulerów i runnable queue.
