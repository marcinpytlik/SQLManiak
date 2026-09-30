# Reference Architecture: SQL Server FCI

## Purpose

Referencyjny model FCI wynikający z istniejącego labu Windows Server 2022 + SQL Server 2022.

## Components

```text
AD / DNS
   |
   +-- File Share Witness
   |
WSFC
   |
   +-- NODE1
   |     +-- local TempDB
   |
   +-- NODE2
         +-- local TempDB

Shared storage
   +-- DATA
   +-- LOG

SQL Server FCI
   +-- VNN
   +-- VIP
```

## Architectural rules

- DATA/LOG na shared storage.
- TempDB lokalny na każdym node, identyczna ścieżka.
- Quorum/witness jawnie skonfigurowane.
- VNN jest nazwą używaną przez klientów.
- Failover jest walidowany przez połączenie po VNN.
- gMSA jest preferowanym modelem konta usługi tam, gdzie został przyjęty.
- Backup/restore pozostaje osobną warstwą DR.

## Operational links

- [FCI Standard](../../standards/ha-dr/)
- [FCI Troubleshooting](../../troubleshooting/ha-dr/)
- [FCI Failover Runbook](../../runbooks/fci-failover/)

## Source

- [FCI Windows Server 2022 + SQL Server 2022](../../docs/FCI-Windows2022-SQL2022/)
