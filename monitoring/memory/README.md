# Monitoring: Memory

## Purpose

Wykrywać realną presję pamięci i oddzielać OS pressure, buffer pool churn i query grant pressure.

## Signals / Metrics

- Memory Grants Pending
- Free List Stalls
- PLE
- Lazy Writes
- Granted Workspace Memory
- OS memory headroom

## Alert vs Trend

- Memory Grants Pending sustained — ALERT
- Free List Stalls sustained — ALERT
- PLE — TREND
- Lazy Writes — TREND/DIAGNOSTIC

## Baseline

PLE i inne liczniki pamięci oceniaj względem własnego baseline; nie używaj uniwersalnego progu jako samodzielnego alertu.

## Correlation

- grants pending vs RESOURCE_SEMAPHORE
- PLE vs lazy writes/page reads
- OS memory vs max server memory
- grants vs plans/query workload

## Severity

HIGH, gdy pressure jest utrzymujący się i wpływa na throughput/latency; pojedynczy spadek PLE nie jest alertem.

## Validation

- DMV memory grants
- OS/SQL memory
- wait stats
- query plans

## Troubleshooting

- [Memory](../../troubleshooting/memory/)
- [Wait Statistics](../../troubleshooting/wait-statistics/)

## Runbooks

- [Memory Pressure Incident](../../runbooks/memory-pressure-incident/)

## Sources of truth

- [Zabbix inventory](../../scripts/zabbix-mssql-monitoring/docs/inventory/01-items-01.md)
- [Memory Internals](../../docs/MemoryInternals/)
