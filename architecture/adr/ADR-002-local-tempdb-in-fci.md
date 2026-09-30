# ADR-002: Local TempDB on SQL Server FCI Nodes

- Status: Accepted
- Date: 2026-09-30
- Owners: SQLManiak / DBA

## Context

Repozytoryjny model FCI dla Windows Server 2022 + SQL Server 2022 używa shared storage dla DATA/LOG oraz lokalnego wolumenu `T:` dla TempDB na każdym węźle.

TempDB jest tworzony od nowa przy starcie SQL Server, dlatego nie wymaga współdzielonego storage w tym modelu.

## Decision drivers

- oddzielenie TempDB od shared DATA/LOG,
- lokalna wydajność storage,
- przewidywalny layout,
- możliwość testowania wpływu TempDB na czas failover.

## Considered options

### Shared TempDB

Nie jest przyjętym modelem w repozytoryjnym FCI.

### Local TempDB with identical path on every node

Przyjęto.

## Decision

Każdy możliwy owner node FCI posiada lokalną ścieżkę TempDB o identycznym układzie.

W obecnym labie:

```text
T:\MSSQL
```

Przed failover wymagane jest potwierdzenie:

- istnienia ścieżki,
- ACL dla konta usługi,
- rozmiarów i autogrowth,
- możliwości utworzenia TempDB po przełączeniu.

## Consequences

### Positive

- TempDB nie zależy od shared DATA/LOG storage,
- możliwe jest użycie lokalnego szybkiego storage,
- prostsze oddzielenie workloadu TempDB.

### Negative / Trade-offs

- konfiguracja musi być identyczna na każdym node,
- brak ścieżki/ACL na jednym node może uniemożliwić start SQL po failover,
- lokalne storage musi być utrzymywane na każdym node.

## Validation

- test failover,
- ERRORLOG po starcie,
- `sys.database_files` w TempDB,
- czas disconnect/reconnect aplikacji.

## Revisit when

- zmienia się storage architecture,
- zmienia się liczba node,
- failover time nie spełnia RTO.

## References

- [FCI Lab](../../docs/FCI-Windows2022-SQL2022/)
- [TempDB Failover Checklist](../../docs/FCI-Windows2022-SQL2022/docs/FCI_Tempdb_Failover_Checklist.md)
- [FCI Failover Runbook](../../runbooks/fci-failover/)
