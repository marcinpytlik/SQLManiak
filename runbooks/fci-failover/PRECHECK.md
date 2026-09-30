# SQL Server FCI Failover — PRECHECK

## 1. Zapisz parametry operacji

```text
FCI instance:
Cluster group:
VNN:
Current owner node:
Target node:
Maintenance window:
Expected application impact:
```

W labie repo wartości przykładowe to:

```text
Cluster group: SQL Server (MSSQLSERVER)
VNN: SQLSRV-FCI
Nodes: NODE1 / NODE2
```

## 2. Sprawdź WSFC

```powershell
Get-Cluster
Get-ClusterNode
Get-ClusterGroup
Get-ClusterResource
Get-ClusterQuorum
```

Potwierdź:

- target node jest online,
- quorum działa,
- grupa FCI jest online,
- nie ma failed resources.

## 3. Sprawdź storage

Potwierdź, że współdzielone zasoby DATA/LOG są online w klastrze.

Lab repo używa shared storage dla DATA/LOG.

## 4. Sprawdź lokalny TempDB na target node

Repo FCI używa lokalnego dysku `T:` dla TempDB na każdym węźle.

Zgodnie z checklistą zweryfikuj:

- identyczne ścieżki TempDB na obu node,
- katalog istnieje,
- konto usługi SQL ma dostęp,
- rozmiary/autogrow są zgodne.

## 5. Sprawdź VNN

Zapisz nazwę wirtualną używaną przez klientów.

W labie:

```text
SQLSRV-FCI
```

## 6. Evidence before

Zachowaj:

- owner node przed failover,
- stan resource group,
- stan quorum,
- stan shared disks,
- bieżący czas,
- możliwość połączenia przez VNN.

## 7. Stop conditions

Nie rozpoczynaj failover, gdy:

- target node nie jest online,
- quorum jest w nieprawidłowym stanie,
- wymagany shared storage jest offline,
- ścieżka lokalnego TempDB na target node nie jest przygotowana,
- istnieje niewyjaśniony failed resource.
