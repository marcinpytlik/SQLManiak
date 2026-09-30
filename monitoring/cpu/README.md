# Monitoring: CPU

## Purpose

Rozpoznawać rzeczywistą presję CPU SQL Server z uwzględnieniem limitów schedulerów i workloadu.

## Signals / Metrics

- host CPU
- SQL process CPU
- other process CPU
- VISIBLE ONLINE schedulers
- runnable tasks per active scheduler
- SOS_SCHEDULER_YIELD
- CPU per database trend

## Alert vs Trend

- CPU % — TREND/DIAGNOSTIC
- runnable queue sustained — ALERT candidate
- scheduler pressure correlation — ALERT candidate
- CPU per database — TREND

## Baseline

Repo świadomie nie aktywuje jednego progu CPU pressure. Najpierw zbierany jest baseline i korelacja schedulerów z E2E.

## Correlation

- SQL CPU vs other CPU
- CPU vs runnable queue
- CPU vs SOS_SCHEDULER_YIELD
- CPU vs E2E latency
- top CPU queries

## Severity

Alert dopiero przy utrzymującej się presji i wpływie na usługę, nie na podstawie pojedynczego CPU %.

## Validation

- scheduler count
- runnable trend
- Query Store/top queries
- E2E/latency

## Troubleshooting

- [CPU](../../troubleshooting/cpu/)
- [Query Performance](../../troubleshooting/query-performance/)

## Runbooks

- [CPU Pressure Incident](../../runbooks/cpu-pressure-incident/)
- [Query Performance Incident](../../runbooks/query-performance-incident/)

## Sources of truth

- [CPU matrix](../../scripts/zabbix-mssql-monitoring/docs/excel-mapping/03-alerts-and-cpu.md)
- [CPU health query](../../scripts/zabbix-mssql-monitoring/custom-queries/sqlmaniak_cpu_health.sql)
