# Runbook: SQL Server FCI Failover

## Cel

Kontrolowane przeniesienie roli SQL Server Failover Cluster Instance na drugi węzeł WSFC oraz potwierdzenie, że instancja jest dostępna przez VNN po failover.

Runbook opiera się na istniejącym labie:

- [FCI Windows Server 2022 + SQL Server 2022](../../docs/FCI-Windows2022-SQL2022/)
- [Smoke-Test.ps1](../../docs/FCI-Windows2022-SQL2022/scripts/tests/Smoke-Test.ps1)
- [TempDB Failover Checklist](../../docs/FCI-Windows2022-SQL2022/docs/FCI_Tempdb_Failover_Checklist.md)

## Zakres

Obejmuje:

- pre-check WSFC/FCI,
- wybór target node,
- kontrolowany `Move-ClusterGroup`,
- walidację VNN,
- kontrolę lokalnego TempDB,
- pomiar czasu niedostępności,
- rollback/failback do poprzedniego node.

## Struktura

- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)
