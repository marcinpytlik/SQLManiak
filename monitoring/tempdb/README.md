# Monitoring: TempDB

## Purpose

Monitorować capacity i symptomy workloadu TempDB: version store, workspace, consumers i growth.

## Signals / Metrics

- allocated/used/free
- top consumers
- version store
- autogrowth
- allocation contention
- filesystem capacity

## Alert vs Trend

- near/full capacity — ALERT
- autogrowth burst — ALERT/TREND
- version store — TREND/DIAGNOSTIC
- top consumer — DIAGNOSTIC

## Baseline

TempDB trzeba oceniać przez pełny cykl workloadu; chwilowy peak nie powinien automatycznie definiować nowego progu.

## Correlation

- version store vs long transactions/RCSI-SI
- spills vs query plans/memory grants
- growth vs filesystem
- FCI failover vs local path

## Severity

HIGH gdy grozi brak miejsca lub wpływ na całą instancję.

## Validation

- TempDB health pack
- file sizes/growth
- top consumers
- version store
- waits

## Troubleshooting

- [TempDB](../../troubleshooting/tempdb/)

## Runbooks

- [TempDB Emergency](../../runbooks/tempdb-emergency/)
- [FCI Failover](../../runbooks/fci-failover/)

## Sources of truth

- [DBA Daily Pack TempDB](../../tools/DBADaillyPack/sql/03_Tempdb_Health.sql)
- [TempDB Standard](../../standards/tempdb/)
