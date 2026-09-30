# Monitoring: I/O

## Purpose

Monitorować latency i workload storage bez mylenia wysokiego I/O z awarią storage.

## Signals / Metrics

- read stall ms/op
- write stall ms/op
- I/O ops/bytes
- PAGEIOLATCH waits
- WRITELOG waits
- file-level latency

## Alert vs Trend

- latency — TREND, alert po strojeniu progów
- PAGEIOLATCH/WRITELOG — DIAGNOSTIC
- storage errors — ALERT

## Baseline

Repo świadomie pozostawia progi I/O do strojenia na realnych danych zamiast aktywować arbitralne wartości.

## Correlation

- latency vs workload volume
- PAGEIOLATCH vs query reads
- WRITELOG vs log throughput/autogrowth
- backup/CHECKDB window vs I/O

## Severity

HIGH dla trwałej degradacji z wpływem na usługę lub błędów storage; same wartości stall bez kontekstu są niewystarczające.

## Validation

- per-file stats
- volume metrics
- wait delta
- top read/write queries

## Troubleshooting

- [I/O](../../troubleshooting/io/)
- [Wait Statistics](../../troubleshooting/wait-statistics/)

## Runbooks

- [I/O Latency Incident](../../runbooks/io-latency-incident/)

## Sources of truth

- [Zabbix alerts matrix](../../scripts/zabbix-mssql-monitoring/docs/excel-mapping/03-alerts-and-cpu.md)
- [DBA Daily Pack](../../tools/DBADaillyPack/README.md)
