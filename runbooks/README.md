# Runbooks

Runbook to powtarzalna procedura operacyjna dla DBA.

Dobry runbook odpowiada na pytania:

- kiedy go użyć,
- jakie są prerequisites,
- jakie kroki wykonać,
- jak zweryfikować wynik,
- kiedy przerwać,
- jak wykonać rollback,
- gdzie znaleźć logi i skrypty pomocnicze.

## Model runbooka

Każdy runbook używa wspólnego układu:

```text
operation/
├── README.md
├── PRECHECK.md
├── RUNBOOK.md
├── VALIDATION.md
└── ROLLBACK.md
```

Do nowych runbooków używaj [template](../templates/RUNBOOK-TEMPLATE.md).

---

# Recovery / Data Protection

- [Backup / Restore / Recovery](backup-restore-recovery/)
  - FULL / DIFF / LOG / STOPAT,
  - realny restore test,
  - DBCC CHECKDB,
  - walidacja RPO/RTO.

- [DBCC CHECKDB / Corruption Recovery](checkdb-corruption-recovery/)
  - corruption triage,
  - suspect_pages,
  - page/full restore,
  - walidacja integralności.

- [Log Shipping DR Failover](log-shipping-dr-failover/)
  - tail-log,
  - domknięcie chaina,
  - RECOVERY na DR,
  - cutover aplikacji.

---

# HA / DR

- [SQL Server FCI Failover](fci-failover/)
  - WSFC/quorum/resources,
  - Move-ClusterGroup,
  - VNN,
  - lokalny TempDB,
  - rollback/failback.

- [Availability Group Planned Failover](ag-planned-failover/)
  - synchronization health,
  - role change,
  - listener,
  - log send / redo queues.

---

# Performance / Incident Response

- [Blocking Emergency Mitigation](blocking-emergency/)
  - head blocker,
  - blocking chain,
  - controlled KILL,
  - rollback monitoring.

- [Deadlock Incident Response](deadlock-incident-response/)
  - deadlock graph,
  - access order,
  - root cause,
  - retry jako resilience.

- [CPU Pressure Incident](cpu-pressure-incident/)
  - host vs SQL CPU,
  - schedulers,
  - runnable queue,
  - top CPU workload.

- [Wait Statistics Incident Analysis](wait-statistics-incident/)
  - snapshot/delta,
  - wait categories,
  - signal/resource,
  - korelacja z workloadem.

- [I/O Latency Incident](io-latency-incident/)
  - per-file latency,
  - PAGEIOLATCH / WRITELOG,
  - workload vs storage.

- [Memory Pressure Incident](memory-pressure-incident/)
  - memory grants,
  - RESOURCE_SEMAPHORE,
  - OS vs SQL pressure.

- [Query Performance Incident](query-performance-incident/)
  - Query Store / plan cache,
  - plans,
  - CPU/reads/duration,
  - controlled tuning.

- [Query Store Regression Mitigation](query-store-regression-mitigation/)
  - BEFORE vs INCIDENT,
  - Force Plan,
  - Query Store Hints,
  - rollback/unforce.

- [TempDB Emergency](tempdb-emergency/)
  - capacity,
  - version store,
  - spills,
  - allocation contention.

---

# Operations / Automation

- [SQL Agent Job Recovery](sql-agent-job-recovery/)
  - failed/missed/long-running jobs,
  - owner/proxy/credential,
  - retry,
  - output validation.

- [Transactional Replication Incident Recovery](replication-incident-recovery/)
  - agent jobs,
  - distribution errors,
  - backlog,
  - reinitialization only when required.

- [SQL Server Patching](sql-server-patching/)
  - patching window,
  - controlled disable/restore of jobs,
  - service/HA validation,
  - rollback.

---

# Migration

- [SQL Server 2016 to 2022 Migration](sql2016-to-2022-migration/)
  - precheck,
  - side-by-side backup/restore,
  - postcheck,
  - Query Store,
  - observation window,
  - rollback period.

---

# Jak korzystać

Runbook odpowiada na pytanie:

> **Jak bezpiecznie wykonać operację albo ograniczyć skutki incydentu?**

Jeżeli najpierw trzeba ustalić przyczynę problemu, zacznij od:

- [Troubleshooting](../troubleshooting/)

Runbook powinien linkować do istniejących skryptów, laboratoriów i checklist zamiast kopiować drugi source of truth.
