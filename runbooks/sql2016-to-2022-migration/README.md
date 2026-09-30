# Runbook: SQL Server 2016 to 2022 Migration

## Cel

Migracja side-by-side baz i zależności z SQL Server 2016 do SQL Server 2022 z kontrolowanym cutover i okresem rollback.

## Kiedy użyć

- migracja 2016→2022
- przeniesienie baz na nową instancję 2022

## Struktura

- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth

- [Migration checklist](../../checklists/migration/sql2016_to_2022.md)
- [DBMigrationPack checklist](../../tools/DBMigrationPack/CHECKLIST.md)
- [Post-migration checklist](../../docs/post_migration_checklist.md)
- [Query Store troubleshooting](../../troubleshooting/query-store/)

## Zasada

> Restore bazy to tylko środek procesu migracji; sukces obejmuje loginy, joby, zależności, compatibility, Query Store, smoke tests i okres obserwacji.
