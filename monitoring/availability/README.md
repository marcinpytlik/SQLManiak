# Monitoring: Availability

## Purpose

Wykrywać realną niedostępność SQL Server i odróżniać problem portu, kanału monitoringu, usługi SQL oraz ścieżki E2E.

## Signals / Metrics

- TCP availability
- monitoring channel availability
- E2E response time
- SQL Server restart / uptime
- database state

## Alert vs Trend

- TCP unavailable — ALERT
- monitoring channel unavailable while TCP works — ALERT
- E2E response time — TREND + anomaly candidate
- restart — ALERT
- database state != ONLINE — ALERT

## Baseline

E2E powinno być oceniane względem linii bazowej, nie jednego stałego progu. Repo posiada baseline 1h/24h/7d oraz anomaly score dla E2E.

## Correlation

- TCP vs monitoring channel
- E2E latency vs CPU/I/O/memory
- database state vs HA/DR events

## Severity

Dostępność krytycznej instancji/bazy może być HIGH/DISASTER; severity zależy od krytyczności usługi i zakresu wpływu.

## Validation

- test TCP
- test E2E
- połączenie SQL
- database state
- notification path

## Troubleshooting

- [HA/DR](../../troubleshooting/ha-dr/)
- [SQL Agent](../../troubleshooting/sql-agent/)

## Runbooks

- [FCI Failover](../../runbooks/fci-failover/)
- [AG Planned Failover](../../runbooks/ag-planned-failover/)

## Sources of truth

- [Zabbix alerts matrix](../../scripts/zabbix-mssql-monitoring/docs/excel-mapping/03-alerts-and-cpu.md)
- [Zabbix inventory](../../scripts/zabbix-mssql-monitoring/docs/inventory/01-items-01.md)
