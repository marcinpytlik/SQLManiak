# Monitoring

Warstwa monitoringu odpowiada na pytanie:

> **Czy środowisko nadal działa zgodnie ze standardem i czy pojawia się sygnał wymagający reakcji?**

Monitoring nie powinien być zbiorem przypadkowych progów. Każdy moduł opisuje:

- sygnały / metryki,
- ALERT vs TREND vs DIAGNOSTIC,
- baseline,
- korelację,
- severity,
- walidację,
- powiązany troubleshooting,
- powiązany runbook,
- source of truth.

---

# Availability

- [Availability](availability/)
  - TCP,
  - monitoring channel,
  - E2E,
  - restart,
  - database state.

---

# Data Protection

- [Backup & Recovery](backup-recovery/)
  - FULL / DIFF / LOG SLA,
  - recovery model,
  - restore tests,
  - RPO/RTO.

---

# Operations

- [SQL Server Agent](sql-agent/)
  - failed,
  - missed,
  - disabled,
  - long-running,
  - notification path.

- [Transactional Replication](replication/)
  - agent state,
  - distribution errors,
  - backlog,
  - latency.

---

# Performance

- [CPU](cpu/)
- [Memory](memory/)
- [I/O](io/)
- [Blocking & Deadlocks](blocking-deadlocks/)
- [TempDB](tempdb/)
- [Query Store](query-store/)

---

# Capacity

- [Database Capacity](database-capacity/)
  - ROWS,
  - filegroups,
  - log,
  - VLF,
  - growth,
  - time-to-full.

---

# HA / DR

- [HA / DR](ha-dr/)
  - quorum,
  - replica role,
  - connected state,
  - synchronization health,
  - log send queue,
  - redo queue,
  - listener.

---

# Monitoring model

```text
Standard
   |
   v
Expected state
   |
   v
Monitoring
   |
   +--> ALERT
   +--> TREND
   +--> DIAGNOSTIC
   |
   v
Troubleshooting
   |
   v
Runbook
```

## ALERT

Sygnał wymagający reakcji operacyjnej.

Przykłady:

- database offline,
- failed critical job,
- backup SLA breach,
- replica disconnected.

## TREND

Sygnał wymagający obserwacji w czasie.

Przykłady:

- CPU per baza,
- filegroup growth,
- restore duration,
- I/O latency.

## DIAGNOSTIC

Metryka używana do korelacji podczas incydentu.

Przykłady:

- wait type,
- PLE,
- PAGEIOLATCH,
- Query Store runtime stats.

---

# Baseline-first

Dla metryk silnie zależnych od workloadu nie zakładamy automatycznie jednego uniwersalnego progu.

Model:

```text
collect
→ baseline
→ correlate
→ tune threshold
→ validate alert quality
```

Istniejące dashboardy pozostają w [../dashboards](../dashboards/).

Główne implementacje monitoringu:

- [Zabbix MSSQL Monitoring](../scripts/zabbix-mssql-monitoring/)
- [DBACentralRepository](../scripts/DBACentralRepository_v3/)
- [DBA Daily Pack](../tools/DBADaillyPack/)
