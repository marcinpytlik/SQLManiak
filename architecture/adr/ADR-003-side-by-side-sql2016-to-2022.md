# ADR-003: Side-by-Side Migration from SQL Server 2016 to 2022

- Status: Accepted
- Date: 2026-09-30
- Owners: SQLManiak / DBA

## Context

Repo zawiera checklisty i DBMigrationPack dla migracji SQL Server 2016 → 2022.

Materiały wskazują side-by-side jako preferowane podejście względem in-place upgrade oraz zakładają okres rollback, w którym source pozostaje dostępny jako kontrolowany punkt powrotu.

## Decision drivers

- możliwość precheck i test restore,
- kontrolowany cutover,
- możliwość porównania konfiguracji,
- rollback window,
- rozdzielenie zmiany engine version od compatibility level.

## Considered options

### In-place upgrade

Możliwy, ale repo nie traktuje go jako preferowanego scenariusza.

### Side-by-side migration

Przyjęto jako domyślny wzorzec.

## Decision

Migracja 2016 → 2022 jest wykonywana side-by-side:

```text
precheck
→ prepare destination
→ rehearsal restore
→ freeze
→ backup/restore
→ postcheck
→ cutover
→ observation window
→ decommission source
```

Compatibility level nie jest podnoszony bez osobnej walidacji i baseline Query Store.

## Consequences

### Positive

- możliwość próbnego restore,
- łatwiejszy rollback,
- możliwość porównania source/destination,
- separacja engine upgrade i optimizer behavior change.

### Negative / Trade-offs

- wymaga równoległej infrastruktury,
- trzeba migrować loginy, joby, linked servers, credentials i inne zależności poza bazą,
- przez okres przejściowy utrzymywane są dwa środowiska.

## Validation

- DBMigrationPack pre/postcheck,
- smoke tests aplikacji,
- Query Store baseline/after,
- backup/restore test,
- observation window.

## Revisit when

- infrastruktura nie pozwala na side-by-side,
- aplikacja wymaga in-place z udokumentowanych powodów.

## References

- [Migration Checklist](../../checklists/migration/sql2016_to_2022.md)
- [DBMigrationPack](../../tools/DBMigrationPack/)
- [Migration Runbook](../../runbooks/sql2016-to-2022-migration/)
