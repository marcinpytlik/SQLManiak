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

## Dostępne runbooki

- [Backup / Restore / Recovery](backup-restore-recovery/)
  - pre-check chaina i miejsca,
  - FULL / DIFF / LOG / STOPAT,
  - realny restore test,
  - DBCC CHECKDB,
  - walidacja RPO/RTO.

- [SQL Server FCI Failover](fci-failover/)
  - pre-check WSFC/quorum/resources,
  - kontrolowany Move-ClusterGroup,
  - walidacja VNN,
  - lokalny TempDB,
  - rollback/failback.

## Model runbooka

Nowe procedury powinny korzystać z układu:

```text
operation/
├── README.md
├── PRECHECK.md
├── RUNBOOK.md
├── VALIDATION.md
└── ROLLBACK.md
```

Do nowych runbooków używaj [template](../templates/RUNBOOK-TEMPLATE.md).
