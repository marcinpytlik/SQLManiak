# Porównanie istniejącego `patch` z pierwotnym PatchAudit v2

| Obszar | DBACentralRepository v3 | Pierwotne v2 | Decyzja |
|---|---|---|---|
| Katalog buildów | `patch.SqlBuildCatalog` | brak | zostaje istniejący |
| Historia buildów | `patch.InstanceBuildHistory` | `patch.AuditRun` zawierał build | zostaje istniejąca historia |
| Ocena aktualności | `patch.PatchAssessment` | częściowo `AuditFinding` | rozdzielamy compliance od audytu okna |
| Wyjątki | `patch.PatchException` | brak | zostaje istniejący |
| Bazy | `db.DatabaseSnapshot` | `patch.DatabaseSnapshot` | bez duplikatu |
| Backupy | `backup.BackupHistory` | `patch.BackupSnapshot` | bez duplikatu |
| AG | `ha.*Snapshot` | `patch.AG*Snapshot` | bez duplikatu |
| Suspect pages | `maintenance.SuspectPageSnapshot` | `patch.SuspectPageSnapshot` | bez duplikatu |
| Linked Servers | `config.LinkedServerSnapshot` | `patch.LinkedServerSnapshot` | bez duplikatu; collector poprawiony |
| Trace flags | `config.TraceFlagSnapshot` | tylko TF 11042 w procedurze | wykorzystujemy istniejącą tabelę; collector poprawiony |
| Query Store detail | brak | `patch.QueryStoreSnapshot` | dodane jako `config.QueryStoreSnapshot` |
| `SESSION_CONTEXT` | brak | tymczasowe wyszukiwanie | dodane jako `patch.CodeRiskSnapshot` |
| PRE/POST | brak | `patch.AuditRun` | dodane jako `PatchCycle` + `PatchCyclePhase` |
| Findings | brak per okno | `patch.AuditFinding` | dodane jako `patch.PatchFinding` |

Najważniejsza zmiana: PRE i POST wskazują na istniejący `dbo.ScanRun`. Dzięki temu jedna kolekcja jest źródłem danych dla całego repozytorium i dla procesu patchowania.
