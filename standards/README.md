# Standards

Standardy określają **jak chcemy zarządzać środowiskiem SQL Server**.

Standard nie jest instrukcją krok po kroku. Opisuje:

- wymagany stan,
- rekomendacje,
- rzeczy niedozwolone,
- konfigurację domyślną,
- wyjątki,
- sposób walidacji,
- ownership,
- cykl przeglądu.

Do tworzenia nowych standardów używaj [template](../templates/STANDARD-TEMPLATE.md).

---

# Data Protection / Recovery

- [Backup & Recovery](backup-recovery/)
  - recovery model,
  - FULL / DIFF / LOG,
  - restore test,
  - RPO/RTO,
  - encryption,
  - system databases.

---

# Database Configuration

- [TempDB](tempdb/)
  - capacity,
  - version store,
  - growth,
  - FCI local TempDB.

- [Database Files & Autogrowth](database-files-autogrowth/)
  - fixed-MB autogrowth,
  - pre-sizing,
  - data/log layout,
  - AUTO_SHRINK / AUTO_CLOSE,
  - PAGE_VERIFY.

- [Query Store](query-store/)
  - READ_WRITE,
  - retention,
  - storage,
  - forced plans,
  - baseline przed compatibility changes.

---

# Operations / Automation

- [SQL Server Agent](sql-agent/)
  - technical owners,
  - schedules,
  - proxy/credential,
  - failed/missed jobs,
  - notifications,
  - output validation.

---

# Security

- [Security & Least Privilege](security-least-privilege/)
  - role-based permissions,
  - ograniczenie sysadmin/db_owner,
  - orphaned users,
  - TRUSTWORTHY,
  - service/job execution context,
  - TDE/keys/certificates.

---

# HA / DR

- [HA / DR](ha-dr/)
  - FCI vs AG,
  - WSFC/quorum,
  - listener/VNN,
  - synchronization,
  - failover testing,
  - RPO/RTO,
  - backup jako część DR.

---

# Monitoring

- [Monitoring](monitoring/)
  - availability,
  - backup SLA,
  - database state,
  - SQL Agent,
  - CPU/memory/I/O,
  - blocking/deadlocks,
  - HA/DR,
  - baseline vs static thresholds.

---

# Jak korzystać

Model DBA Library:

```text
Standard
   |
   v
Jak powinno być
   |
   v
Monitoring
   |
   v
Czy nadal tak jest
   |
   v
Troubleshooting
   |
   v
Dlaczego jest źle
   |
   v
Runbook
   |
   v
Jak bezpiecznie wykonać zmianę / recovery
```

Standard jest **source of truth dla oczekiwanego stanu**.

Troubleshooting i runbooki powinny linkować do standardu, gdy operacja lub diagnoza zależy od oczekiwanej konfiguracji.
