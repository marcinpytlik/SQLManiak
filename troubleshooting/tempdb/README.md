# Troubleshooting: TempDB

## Symptoms

- szybki wzrost TempDB,
- contention,
- wysokie wykorzystanie version store,
- problemy z sort/hash spill,
- brak miejsca,
- problemy po failover FCI przy lokalnym TempDB.

## First checks

1. Rozmiar i wolne miejsce.
2. Top consumers.
3. Version store.
4. Aktywne transakcje.
5. Allocation contention.
6. Autogrowth.
7. Konfiguracja plików.
8. W FCI: dostępność lokalnej ścieżki po failover.

## Existing sources of truth

### DBA Daily Pack

- [03_Tempdb_Health.sql](../../tools/DBADaillyPack/sql/03_Tempdb_Health.sql)

### TempDB Control

- [TempDB Control](../../docs/Inside_SQL_Server2022/Tempdb_Control/)
- [TempDB Shrink](../../docs/Inside_SQL_Server2022/Tempdb_Control/TempDB_Shrink.md)
- [TempDB Shrink Runbook](../../docs/Inside_SQL_Server2022/Tempdb_Control/runbooks/TempDB_Shrink.md)

### FCI

- [FCI TempDB](../../docs/FCI-Windows2022-SQL2022/docs/FCI_Tempdb.md)
- [FCI TempDB Failover](../../docs/FCI-Windows2022-SQL2022/docs/FCI_Tempdb_Failover.md)
- [FCI TempDB Failover Checklist](../../docs/FCI-Windows2022-SQL2022/docs/FCI_Tempdb_Failover_Checklist.md)

## Diagnosis

Rozróżnij co najmniej:

- brak capacity,
- problem konfiguracji,
- version store,
- workspace spills,
- allocation contention,
- pojedynczy runaway query/process.

## Validation

Po zmianie sprawdź trend wykorzystania TempDB i zachowanie w pełnym cyklu workloadu, nie tylko bezpośrednio po interwencji.
