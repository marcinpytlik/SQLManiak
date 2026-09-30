# Monitoring: Backup & Recovery

## Purpose

Pilnować, czy aktualność backupów odpowiada wymaganiom recovery i czy istnieje realna możliwość odtworzenia.

## Signals / Metrics

- age of last FULL backup
- age of last DIFF backup
- age of last LOG backup
- recovery model
- backup failures
- restore test result/duration

## Alert vs Trend

- backup SLA breach — ALERT
- recovery model mismatch — ALERT lub compliance
- backup duration/size — TREND
- restore duration — TREND + capacity/RTO

## Baseline

Progi wieku backupu wynikają z polityki RPO, nie z uniwersalnych wartości.

## Correlation

- backup age vs recovery model
- backup failures vs SQL Agent
- restore duration vs I/O
- log backup age vs log growth/log_reuse_wait_desc

## Severity

Breach LOG/FULL SLA dla bazy krytycznej może być HIGH/DISASTER zależnie od RPO i braku alternatywnego recovery path.

## Validation

- backup history w msdb
- restore test
- DBCC CHECKDB po restore
- RPO/RTO review

## Troubleshooting

- [Backup/Restore](../../troubleshooting/backup-restore/)

## Runbooks

- [Backup/Restore/Recovery](../../runbooks/backup-restore-recovery/)
- [Corruption Recovery](../../runbooks/checkdb-corruption-recovery/)

## Sources of truth

- [Zabbix backup SLA](../../scripts/zabbix-mssql-monitoring/docs/excel-mapping/03-alerts-and-cpu.md)
- [Backup Strategy](../../docs/Inside_SQL_Server2022_Databases/Backup_Strategy.md)
