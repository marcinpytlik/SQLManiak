# Monitoring: Database Capacity

## Purpose

Wykrywać ryzyko wyczerpania przestrzeni i obserwować trend wzrostu baz, logów i filegroupów.

## Signals / Metrics

- ROWS allocated/used/free
- filegroup used/free
- timeleft()
- log used %
- log time-to-full
- VLF count
- growth events

## Alert vs Trend

- log usage high — ALERT
- time-to-full — ALERT candidate
- ROWS/filegroup usage — TREND until tuned
- VLF count — TREND/compliance
- growth events — TREND

## Baseline

Progi filegroup/ROWS powinny być dobrane po zebraniu realnych trendów; repo nie aktywuje ich wszędzie automatycznie.

## Correlation

- growth vs business load
- log usage vs log backups/log_reuse_wait_desc
- ROWS timeleft vs filesystem capacity
- VLF vs growth configuration

## Severity

Severity zależy od przewidywanego czasu do wyczerpania i krytyczności bazy.

## Validation

- file/filegroup metrics
- filesystem free space
- growth history
- autogrowth configuration

## Troubleshooting

- [I/O](../../troubleshooting/io/)
- [TempDB](../../troubleshooting/tempdb/)

## Runbooks

- [TempDB Emergency](../../runbooks/tempdb-emergency/)
- [Backup/Restore/Recovery](../../runbooks/backup-restore-recovery/)

## Sources of truth

- [Zabbix capacity matrix](../../scripts/zabbix-mssql-monitoring/docs/excel-mapping/03-alerts-and-cpu.md)
- [Files & Autogrowth Standard](../../standards/database-files-autogrowth/)
