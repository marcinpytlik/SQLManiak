# DBA Library Cross-Link Map

Ta mapa łączy warstwy SQLManiak DBA Library według domeny.

Model:

```text
Architecture / ADR
        ↓
Standards
        ↓
Monitoring
        ↓
Troubleshooting
        ↓
Runbooks
        ↓
Existing source of truth
```

| Domain | Architecture / ADR | Standard | Monitoring | Troubleshooting | Runbook |
|---|---|---|---|---|---|
| Backup / Recovery | [DBA Library model](../architecture/adr/ADR-001-dba-library-operating-model.md) | [Backup & Recovery](../standards/backup-recovery/) | [Backup & Recovery](../monitoring/backup-recovery/) | [Backup / Restore](../troubleshooting/backup-restore/) | [Backup / Restore / Recovery](../runbooks/backup-restore-recovery/) |
| Corruption / CHECKDB | [DBA Library model](../architecture/adr/ADR-001-dba-library-operating-model.md) | [Backup & Recovery](../standards/backup-recovery/) | [Backup & Recovery](../monitoring/backup-recovery/) | [Backup / Restore](../troubleshooting/backup-restore/) | [CHECKDB / Corruption Recovery](../runbooks/checkdb-corruption-recovery/) |
| TempDB | [Local TempDB in FCI](../architecture/adr/ADR-002-local-tempdb-in-fci.md) | [TempDB](../standards/tempdb/) | [TempDB](../monitoring/tempdb/) | [TempDB](../troubleshooting/tempdb/) | [TempDB Emergency](../runbooks/tempdb-emergency/) |
| Files / Capacity | [Monitoring architecture](../architecture/reference/monitoring-reference-architecture.md) | [Files & Autogrowth](../standards/database-files-autogrowth/) | [Database Capacity](../monitoring/database-capacity/) | [I/O](../troubleshooting/io/) | [I/O Latency Incident](../runbooks/io-latency-incident/) |
| Query Store | [QS baseline before compat](../architecture/adr/ADR-004-query-store-baseline-before-compat-change.md) | [Query Store](../standards/query-store/) | [Query Store](../monitoring/query-store/) | [Query Store](../troubleshooting/query-store/) | [QS Regression Mitigation](../runbooks/query-store-regression-mitigation/) |
| Query Performance | [QS baseline before compat](../architecture/adr/ADR-004-query-store-baseline-before-compat-change.md) | [Query Store](../standards/query-store/) | [CPU](../monitoring/cpu/) / [I/O](../monitoring/io/) | [Query Performance](../troubleshooting/query-performance/) | [Query Performance Incident](../runbooks/query-performance-incident/) |
| CPU | [Baseline-first monitoring](../architecture/adr/ADR-005-baseline-first-monitoring.md) | [Monitoring](../standards/monitoring/) | [CPU](../monitoring/cpu/) | [CPU](../troubleshooting/cpu/) | [CPU Pressure Incident](../runbooks/cpu-pressure-incident/) |
| Memory | [Baseline-first monitoring](../architecture/adr/ADR-005-baseline-first-monitoring.md) | [Monitoring](../standards/monitoring/) | [Memory](../monitoring/memory/) | [Memory](../troubleshooting/memory/) | [Memory Pressure Incident](../runbooks/memory-pressure-incident/) |
| I/O | [Baseline-first monitoring](../architecture/adr/ADR-005-baseline-first-monitoring.md) | [Files & Autogrowth](../standards/database-files-autogrowth/) | [I/O](../monitoring/io/) | [I/O](../troubleshooting/io/) | [I/O Latency Incident](../runbooks/io-latency-incident/) |
| Wait Statistics | [Baseline-first monitoring](../architecture/adr/ADR-005-baseline-first-monitoring.md) | [Monitoring](../standards/monitoring/) | [CPU](../monitoring/cpu/) / [I/O](../monitoring/io/) / [Memory](../monitoring/memory/) | [Wait Statistics](../troubleshooting/wait-statistics/) | [Wait Statistics Incident](../runbooks/wait-statistics-incident/) |
| Blocking | [Baseline-first monitoring](../architecture/adr/ADR-005-baseline-first-monitoring.md) | [Monitoring](../standards/monitoring/) | [Blocking & Deadlocks](../monitoring/blocking-deadlocks/) | [Blocking](../troubleshooting/blocking/) | [Blocking Emergency](../runbooks/blocking-emergency/) |
| Deadlocks | [Baseline-first monitoring](../architecture/adr/ADR-005-baseline-first-monitoring.md) | [Monitoring](../standards/monitoring/) | [Blocking & Deadlocks](../monitoring/blocking-deadlocks/) | [Deadlocks](../troubleshooting/deadlocks/) | [Deadlock Incident Response](../runbooks/deadlock-incident-response/) |
| SQL Agent | [DBA Library model](../architecture/adr/ADR-001-dba-library-operating-model.md) | [SQL Agent](../standards/sql-agent/) | [SQL Agent](../monitoring/sql-agent/) | [SQL Agent](../troubleshooting/sql-agent/) | [SQL Agent Job Recovery](../runbooks/sql-agent-job-recovery/) |
| Replication | [DBA Library model](../architecture/adr/ADR-001-dba-library-operating-model.md) | [Monitoring](../standards/monitoring/) | [Replication](../monitoring/replication/) | [Replication](../troubleshooting/replication/) | [Replication Incident Recovery](../runbooks/replication-incident-recovery/) |
| FCI | [FCI reference architecture](../architecture/reference/fci-reference-architecture.md) | [HA / DR](../standards/ha-dr/) | [HA / DR](../monitoring/ha-dr/) | [HA / DR](../troubleshooting/ha-dr/) | [FCI Failover](../runbooks/fci-failover/) |
| Availability Groups | [DBA Library model](../architecture/adr/ADR-001-dba-library-operating-model.md) | [HA / DR](../standards/ha-dr/) | [HA / DR](../monitoring/ha-dr/) | [HA / DR](../troubleshooting/ha-dr/) | [AG Planned Failover](../runbooks/ag-planned-failover/) |
| Log Shipping / DR | [DBA Library model](../architecture/adr/ADR-001-dba-library-operating-model.md) | [HA / DR](../standards/ha-dr/) | [HA / DR](../monitoring/ha-dr/) | [Backup / Restore](../troubleshooting/backup-restore/) | [Log Shipping DR Failover](../runbooks/log-shipping-dr-failover/) |
| Security / Least Privilege | [Secure export ADR](../scripts/ssis-secure-export-poc/ADR-001-secure-export-without-unconstrained-delegation.md) | [Security & Least Privilege](../standards/security-least-privilege/) | [Monitoring](../standards/monitoring/) | [SQL Agent](../troubleshooting/sql-agent/) | [SQL Agent Job Recovery](../runbooks/sql-agent-job-recovery/) |
| Migration 2016 → 2022 | [Migration reference architecture](../architecture/reference/migration-reference-architecture.md) | [Query Store](../standards/query-store/) / [Backup](../standards/backup-recovery/) | [Query Store](../monitoring/query-store/) | [Query Performance](../troubleshooting/query-performance/) | [Migration Runbook](../runbooks/sql2016-to-2022-migration/) |
| Patching | [DBA Library model](../architecture/adr/ADR-001-dba-library-operating-model.md) | [SQL Agent](../standards/sql-agent/) / [HA/DR](../standards/ha-dr/) | [SQL Agent](../monitoring/sql-agent/) / [HA/DR](../monitoring/ha-dr/) | [SQL Agent](../troubleshooting/sql-agent/) | [SQL Server Patching](../runbooks/sql-server-patching/) |

## Rule

Jeżeli powstaje nowy moduł w jednej warstwie, sprawdź czy istnieje odpowiadający mu element w pozostałych warstwach.

Nie trzeba tworzyć sztucznego dokumentu tylko po to, żeby wypełnić tabelę. Jeżeli istniejący artefakt jest właściwym source of truth, linkuj do niego.
