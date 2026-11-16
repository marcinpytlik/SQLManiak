# SQLManiak Daily Health Check v1.7 — SQL repository

## Architecture

This version **does not create CSV files**. It reads the existing v1.5 DHC result sets from each monitored instance and writes everything to the central `SQLManiakHealthHistory` database. `@SaveHistory` in the source v1.5 script is forced to 0 to avoid double writes.

Data model:

- `dhc.Run` — one run per instance, timestamp, status, number of rows, error.
- `dhc.ResultBatch` — **all columns and all rows** from every DHC result set, as JSON batches of up to 100 rows (configurable). Empty result sets retain their column definitions.
- `dhc.Alert` — all DHC WARNING and CRITICAL records plus new TempDB alerts, searchable without parsing JSON.
- `dhc.TempDBSnapshot` — normalized tempdb data/log, Version Store, growth and transaction-age snapshot.
- `dhc.TempDBSession` — up to 20 top sessions per sample; indexed IDs, measured values and full JSON record.
- `dhc.TempDBFile` — data/log file inventory, configured growth, volume space and next-growth assessment.
- `dhc.vTempDBTrend` and `dhc.vDailyAlerts` — reporting views.

A **daily** collector provides point-in-time evidence and historical trends. It does **not** reconstruct a short incident that occurred between daily runs. A separate every-10-second incident recorder is a future module, not part of v1.7.

## Files

- `01_Repository.sql` — run once on central repository SQL Server.
- `02_TempDB_Collect.sql` — read-only source query, returns overview, sessions, and files.
- `03_Run-DHC-v1_7.ps1` — collector and database writer, PowerShell 7.5+ with SqlServer module.
- **Existing** `SQLManiak_Daily_Health_Check_v1_5_CSV.sql` — **required**, not included in this package because it was not available as a complete source in this conversation. Keep this file next to the PS script, or supply `-SqlFile`.

## Installation

1. On the repository instance, run `01_Repository.sql` as a deployment administrator. It creates `SQLManiakHealthHistory` only if absent and adds schema `dhc` and associated tables; it does not drop existing data.
2. Grant the collector account `SELECT`/`INSERT`/`UPDATE` on required repository tables, or appropriate rights under the `dhc` schema; no `db_owner` or `sysadmin` is required for routine ingestion. For example (replace with your actual principal and scope):

```sql
USE SQLManiakHealthHistory;
CREATE USER [DOMAIN\sqlmaniak_dhc] FOR LOGIN [DOMAIN\sqlmaniak_dhc];
GRANT SELECT, INSERT, UPDATE ON SCHEMA::dhc TO [DOMAIN\sqlmaniak_dhc];
```

3. The source account needs access to DMVs (on SQL Server 2022, typically `VIEW SERVER PERFORMANCE STATE`, and additional rights for other v1.5 DHC checks). The repository account may be different.
4. Install `SqlServer` for PowerShell 7.5+: `Install-Module SqlServer -Scope CurrentUser`.

## Run one instance

```powershell
$repo = 'Server=SQLREPO;Database=SQLManiakHealthHistory;Integrated Security=True;Encrypt=True;TrustServerCertificate=True'
.\03_Run-DHC-v1_7.ps1 `
  -ServerInstance 'SQL01\INST01' `
  -RepositoryConnectionString $repo `
  -SqlFile '.\SQLManiak_Daily_Health_Check_v1_5_CSV.sql' `
  -TrustServerCertificate
```

`TrustServerCertificate=True` is shown for a lab/internal environment. Prefer a properly trusted TLS certificate in production; do not store SQL passwords in scripts or job command lines.

If TempDB DMVs are inaccessible, `PARTIAL` status and a WARNING are saved while the original DHC result sets remain available. With insufficient repository rights or a main-query failure, the run rolls back completely; the console displays the error.

## Example queries

```sql
USE SQLManiakHealthHistory;

-- Last runs per instance
SELECT TOP(50) ServerInstance, StartedUTC, Status, SourceResultSets, SourceRowCount, ErrorText
FROM dhc.Run ORDER BY StartedUTC DESC;

-- Current alert list
SELECT TOP(100) * FROM dhc.vDailyAlerts ORDER BY StartedUTC DESC;

-- Version Store trend over time
SELECT ServerInstance,StartedUTC,VersionStoreMB,VersionStoreShareUsedPct,
       OldestVersioningSeconds,DataFreePct,LogFreePct
FROM dhc.vTempDBTrend ORDER BY StartedUTC DESC;

-- Sessions associated with a tempdb snapshot
SELECT r.ServerInstance,r.StartedUTC,s.SessionId,s.LoginName,s.SessionAttributedMB,s.VersioningSeconds
FROM dhc.TempDBSession s JOIN dhc.Run r ON r.RunId=s.RunId
ORDER BY r.StartedUTC DESC,s.SessionAttributedMB DESC;

-- Examine an existing full result set; JSON arrays are chunked into batches
SELECT rb.ResultIndex,rb.SectionName,rb.BatchNo,rb.RowCount,rb.RowsJson
FROM dhc.ResultBatch rb
WHERE rb.RunId = 'PUT-RUN-GUID-HERE'
ORDER BY rb.ResultIndex,rb.BatchNo;

-- Retention: preview only, then execute by explicit choice
EXEC dhc.PurgeRuns @OlderThanUTC='2026-09-01', @DryRun=1;
```

## Important limitations and validation

- **No `KILL`, no configuration changes, no automatic cleanup.** All source SQL is read-only except whatever the supplied legacy v1.5 script originally does, for which `@SaveHistory` is explicitly disabled.
- No SQL Server environment is attached to this execution context. Deployment and runtime were **not** tested against a real SQL Server or PowerShell host. Start with a disposable SQL Server 2022 test repository, and inspect row counts, schemas, runtime and access control.
- Complete DHC result sets can contain sensitive server or query information. Restrict access to `dhc.ResultBatch` and encrypt storage/backups appropriately.
- Full JSON histories can grow quickly; size and benchmark repository storage, indexes and ingestion duration before enabling for dozens of instances.
- Older rows are never deleted automatically; `dhc.PurgeRuns` is intentionally manual and defaults to dry-run.
- File next-growth check is per-file. Multiple `AUTOGROW_ALL_FILES` operations on a shared volume can collectively exceed free space; that risk should also be reviewed when enabling production alerts.
- The versioning DMV does not directly attribute all version-store pages to a particular SPID. Treat candidates as diagnostic leads, not proof of responsibility.