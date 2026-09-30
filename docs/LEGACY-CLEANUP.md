> **Content status:** ACTIVE  
> **Canonical entry point:** Legacy / Reference Cleanup  
> **Last reviewed:** 2026-09-30

# Legacy / Reference Cleanup Index

Ten dokument śledzi porządkowanie starszych obszarów repo bez big-bang migration.

## Top-level classification

| Area | Current role | Action |
|---|---|---|
| `standards/` | ACTIVE | canonical policy layer |
| `monitoring/` | ACTIVE | canonical observability layer |
| `troubleshooting/` | ACTIVE | canonical diagnosis layer |
| `runbooks/` | ACTIVE | canonical operational layer |
| `architecture/` | ACTIVE | canonical architecture/ADR layer |
| `RelationalRenaissancePatterns/` | ACTIVE | pozostawić w obecnym modelu |
| `scripts/` | REFERENCE / ACTIVE TOOLING | klasyfikować przy aktualizacji; nie przenosić hurtowo |
| `tools/` | REFERENCE / ACTIVE TOOLING | linkować z nowych warstw |
| `docs/` | REFERENCE / MIXED | stopniowo dodawać canonical entry point |
| `labs/` | LAB | pozostawić jako reprodukcje i ćwiczenia |
| `dashboards/` | ACTIVE ARTIFACTS | linkować z Monitoring |
| `checklists/` | REFERENCE / ACTIVE | linkować ze Standards/Runbooks |
| `courses/` | TRAINING / MIXED | nie traktować jako warstwy operacyjnej |
| `sqlmaniak_blog/` | REFERENCE / CONTENT | poza główną nawigacją operacyjną |
| `ML/` | EXPERIMENT / LAB | klasyfikować per projekt |

## Candidates reviewed during DBA Library work

### Keep as reference/source of truth

- `docs/FCI-Windows2022-SQL2022/`
- `docs/MemoryInternals/`
- `docs/RestoreTest/`
- `docs/VLDB_Survival_Kit_SQLServer_2022/`
- `scripts/zabbix-mssql-monitoring/`
- `scripts/DBACentralRepository_v3/`
- `scripts/SQLManiak-Replication-Diagnostics/`
- `tools/DBADaillyPack/`
- `tools/DBMigrationPack/`
- `tools/SqlStressLab/`
- `tools/SqlLockSimulator/`

### Keep as labs/POC

- `labs/01-query-store-regression/`
- `labs/05-ha_dr/`
- `labs/06-internals/`
- `labs/07-security/`
- `labs/08-dmv/`
- `scripts/ssis-secure-export-poc/`
- `scripts/CDC-POC/`

## Actual LEGACY list

Na tym etapie **nie oznaczamy automatycznie żadnego całego katalogu jako LEGACY**.

Element trafia tutaj dopiero po indywidualnym review i wskazaniu jednoznacznego następcy.

To celowe: starszy materiał może nadal być poprawnym source of truth, laboratorium albo referencją.
