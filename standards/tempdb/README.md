# Standard: TempDB

## Purpose

Zapewnić przewidywalną pojemność i konfigurację TempDB oraz ograniczyć ryzyko contention, niekontrolowanego autogrowth i problemów po failover.

## Scope

Wszystkie instancje SQL Server.

## Requirements

### Required

- TempDB jest monitorowany pod kątem rozmiaru, wolnego miejsca, version store i top consumers.
- Rozmiar początkowy plików jest ustawiony świadomie, a nie pozostawiony przypadkowym wartościom.
- Autogrowth jest ustawiony w MB.
- Pliki danych TempDB mają spójną konfigurację rozmiaru/growth, jeśli mają równoważnie obsługiwać workload.
- Lokalizacja TempDB jest udokumentowana.
- W FCI lokalne ścieżki TempDB istnieją na każdym możliwym owner node i mają wymagane ACL.
- Po failover walidowany jest start TempDB oraz konfiguracja plików.

### Recommended

- Pojemność planować na podstawie rzeczywistego workloadu.
- Monitorować osobno:
  - workspace spills,
  - version store,
  - allocation contention,
  - autogrowth,
  - filesystem capacity.
- Dla FCI używać identycznych ścieżek lokalnych na wszystkich node, jeśli taki model przyjęto.

### Not allowed

- Traktowanie restartu SQL Server jako standardowego sposobu „czyszczenia” TempDB.
- Regularny shrink jako maintenance.
- Zmniejszanie plików podczas aktywnego pressure bez analizy przyczyny.
- Brak lokalnej ścieżki TempDB na jednym z node FCI.

## Default configuration

Nie definiujemy jednej uniwersalnej liczby plików ani rozmiaru dla wszystkich instancji.

Standard wymaga:

```text
pre-size
+
fixed-MB autogrowth
+
monitoring
+
baseline workloadu
```

## Exceptions

Każdy wyjątek od layoutu, liczby plików lub ścieżek musi mieć uzasadnienie wydajnościowe lub infrastrukturalne.

## Validation

- `sys.database_files` w TempDB,
- DBA Daily Pack TempDB health,
- trend autogrowth,
- top consumers/version store,
- test failover dla FCI.

## Ownership

DBA / właściciel instancji.

## Review cycle

- po zmianie workloadu,
- po migracji,
- po failover architecture change,
- po incydencie TempDB,
- minimum kwartalnie dla instancji krytycznych.

## References

- [TempDB Troubleshooting](../../troubleshooting/tempdb/)
- [TempDB Emergency Runbook](../../runbooks/tempdb-emergency/)
- [FCI TempDB Failover Checklist](../../docs/FCI-Windows2022-SQL2022/docs/FCI_Tempdb_Failover_Checklist.md)
