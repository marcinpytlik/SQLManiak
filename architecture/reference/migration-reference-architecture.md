> **Content status:** ACTIVE  
> **Canonical entry point:** Architecture / Reference  
> **Last reviewed:** 2026-09-30

# Reference Architecture: SQL Server 2016 → 2022 Migration

## Purpose

Referencyjny przepływ side-by-side dla migracji SQL Server 2016 do SQL Server 2022.

## Flow

```text
SQL Server 2016
      |
      | precheck + baseline
      v
Prepare SQL Server 2022
      |
      | dependencies / security / storage
      v
Rehearsal restore
      |
      v
Freeze / READ_ONLY source
      |
      v
Backup + Restore
      |
      v
Postcheck
      |
      v
Application cutover
      |
      v
Observation window
      |
      +--> rollback if required
      |
      v
Compatibility-level change
      |
      | Query Store BEFORE/AFTER
      v
Decommission source
```

## Architectural rules

- side-by-side jest domyślnym wzorcem,
- source i destination są porównywane przed cutover,
- zależności server-level migrują osobno,
- compatibility level jest osobną zmianą,
- Query Store baseline poprzedza compatibility change,
- source pozostaje punktem rollback przez uzgodnione okno.

## Operational links

- [Migration Runbook](../../runbooks/sql2016-to-2022-migration/)
- [Query Store Standard](../../standards/query-store/)
- [Query Store Troubleshooting](../../troubleshooting/query-store/)

## Sources

- [DBMigrationPack](../../tools/DBMigrationPack/)
- [Migration Checklist](../../checklists/migration/sql2016_to_2022.md)
