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
- **Existing** `SQLManiak_Daily_Health_Check_v1_5_CSV.sql` — **required**; provide your original v1.5 file next to the PS script or with `-SqlFile`. The collector does not overwrite this file.

### ERRORLOG archive compatibility fix

The v1.7 collector recognizes the known v1.5 ERRORLOG section and substitutes a safer archive loop **in memory**, without changing the original SQL file. It first runs `sp_enumerrorlogs`, skips empty/missing archive files, and scans existing nonempty archives relevant to the last 24 hours (up to the existing `@ErrorLogFilesToScan` cap, default 3, maximum 7), including the archive spanning the 24h boundary. If enumeration fails, it records a warning and tries the current ERRORLOG only. Individual archive errors are recorded as warnings when SQL Server makes them catchable. An unexpected source SQL layout fails explicitly rather than silently skipping the fix.

This fixes the reproduced SQL Server 2022 Linux Docker lab issue where reading a nonexistent ERRORLOG archive caused `Msg 0, Level 11` from `xp_readerrorlog` and aborted the entire DHC run. The script and repository still require an end-to-end retest after pulling the change.

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
## Monitored server inventory (12+ instances)

Run `04_MonitoredServers.sql` once against the **repository** after `01_Repository.sql`. It creates `dhc.MonitoredServer` idempotently and selects current entries. This is an **inventory only**: v1.7 continues to accept one explicit `-ServerInstance` parameter; it does **not** automatically run or schedule monitoring for enabled rows yet.

Columns: unique `ServerInstance` connection endpoint (for a Windows FCI use its VNN/instance name, not a cluster node), optional `DisplayName`, `Environment` (PROD/TEST/DEV/LAB/DR), optional `MonitorGroup` (cluster/site), `IsEnabled` (defaults to **0**, safe onboarding), `IntervalMinutes` (defaults to 1440), `CollectTempDB`, `Notes`, and `CreatedUTC`. For 12 production servers, insert 12 genuine connection endpoints; there is no artificial 12-row limit. A commented Docker lab example is included.

Do **not** store SQL passwords, connection strings with secrets, or credentials in the inventory. Source and repository authentication remain external. There is intentionally no foreign key from historical `dhc.Run` to inventory, so historical records survive a host rename or inventory removal. Existing `01_Repository.sql` is unchanged (local lab edits are preserved).

## Manual central multi-server runner

After deploying the inventory with `04_MonitoredServers.sql`, run `05_Seed-DockerTarget.sql` against the repository to register/enable `127.0.0.1,15434` as LAB. The seed is safe to rerun, but is not automatically executed by any other script.

`06_Run-DHC-MonitoredServers.ps1` reads **enabled** rows from `dhc.MonitoredServer`. It is **preview-only by default**; use `-Execute` to invoke `03_Run-DHC-v1_7.ps1` sequentially per selected endpoint. Optionally filter using `-Environment LAB` or `-ServerInstance '127.0.0.1,15434'`. Failed targets are reported without stopping the remainder; a `PARTIAL` collector run is preserved as `PARTIAL`.

```powershell
# Use existing in-session $builder and $targetCredential from Docker lab setup.
.\06_Run-DHC-MonitoredServers.ps1 `
  -RepositoryConnectionString $builder.ConnectionString `
  -Environment LAB

.\06_Run-DHC-MonitoredServers.ps1 `
  -RepositoryConnectionString $builder.ConnectionString `
  -SqlCredential $targetCredential `
  -Environment LAB -Execute -TrustServerCertificate
```

No scheduler is installed. `IntervalMinutes` is documented desired cadence only, not currently enforced. For future production monitoring across 12 servers, ensure a credential solution for each target or a shared least-privilege identity that works on all instances; the current runner takes **one optional credential** for all selected targets. Do not pass a Docker `sa` credential to production. Secrets are not stored in `dhc.MonitoredServer`; connection-string secrets must not be logged.

## Durable execution history and source connection timeout

Execute `08_ExecutionLog.sql` on the **repository** once after `04_MonitoredServers.sql`, before running the updated `06_Run-DHC-MonitoredServers.ps1 -Execute`. This additive script creates `dhc.ExecutionLog` without altering the collector's historical `dhc.Run` rows.

Each selected enabled instance produces its own `ExecutionId`: a `RUNNING` row is committed in the repository **before** the target is contacted, and a final `COMPLETE`/`PARTIAL`/`FAILED` update is committed afterwards. `RunId` links to `dhc.Run` only for successfully committed collector executions; `FAILED` (such as TCP connection refusal) has null `RunId`, a diagnostic `ErrorText`, and zero rows stored. Historical entries snapshot `ServerId` and `ServerInstance` without a foreign key to current inventory, so removing an inventory record does not discard history. A crash/host shutdown can leave `RUNNING` records; investigate aged RUNNING entries instead of assuming they represent active collectors.

`-ConnectionTimeout` (default **5 seconds**, valid 1–300) is now separate from `-QueryTimeout` (SQL command execution), and is forwarded to `Invoke-Sqlcmd` on each target. Driver retries and DNS/TCP behavior can make observed wall-clock time longer than the configured connection timeout. The inventory itself is read from the repository connection string; this change does not alter its timeout.

```powershell
# Both containers healthy: expect two COMPLETE entries in dhc.ExecutionLog.
.\06_Run-DHC-MonitoredServers.ps1 `
    -RepositoryConnectionString $builder.ConnectionString `
    -SqlCredentialByServer $targetCredentials `
    -Environment LAB -Execute -TrustServerCertificate `
    -ConnectionTimeout 3 -QueryTimeout 30

# Stop ONLY target 2, repeat, then restore it.
docker compose --profile multi-target -f compose.yaml stop sql-target-2
try {
    .\06_Run-DHC-MonitoredServers.ps1 `
        -RepositoryConnectionString $builder.ConnectionString `
        -SqlCredentialByServer $targetCredentials `
        -Environment LAB -Execute -TrustServerCertificate `
        -ConnectionTimeout 3 -QueryTimeout 10
}
finally {
    docker compose --profile multi-target -f compose.yaml start sql-target-2
}
```

```sql
USE SQLManiakHealthHistory;
SELECT TOP (15) ExecutionId,ServerId,ServerInstance,StartedUTC,FinishedUTC,
       Status,RunId,RowsStored,ErrorText
FROM dhc.ExecutionLog
ORDER BY StartedUTC DESC;
-- Expect latest failure-test pair: 15434 COMPLETE with RunId,
-- 15435 FAILED with null RunId and a connection error.
```

The runner never stores passwords or SQL connection strings. A repository logging failure is surfaced in the PowerShell output and may leave an incomplete `RUNNING` row if the final update fails; this is a new failure mode worth monitoring. The added table requires repository `INSERT`/`UPDATE`/`SELECT` privileges consistent with the existing `dhc` schema.

## Monitoring status and overdue detection

After `04_MonitoredServers.sql` and `08_ExecutionLog.sql`, execute **`09_MonitoringStatus.sql`** once on SQL Repository. This installs two read-only views:

- `dhc.vMonitoringStatus`: **one row for every registered server**, including disabled servers and servers with no executions. Contains latest attempt/status/error, latest **COMPLETE** run, elapsed minutes since each, `IsOverdue`, and `MonitoringStatus`.
- `dhc.vMonitoringSummary`: grouped by Environment, with counts of enabled/COMPLETE/FAILED/PARTIAL/NO_DATA/RUNNING and overdue.

`MonitoringStatus` is the **latest attempt's** state: `DISABLED`, `NO_DATA`, `COMPLETE`, `PARTIAL`, `FAILED`, or `RUNNING`. `IsOverdue` is an **independent flag**: 1 when the last attempted check (or a newly registered server's CreatedUTC if no attempt exists) is older than `IntervalMinutes`. It does **not** indicate whether a successful measurement is still fresh, nor does it schedule collection. `LastCompleteUTC`/`MinutesSinceComplete` track only full `COMPLETE` results, never `PARTIAL`. Date computations use UTC. If an older failure is followed by a new successful run, status changes to `COMPLETE`, while prior failure history remains in `dhc.ExecutionLog`.

Run **`10_MonitoringStatus_Checks.sql`** on SQL Repository for four non-destructive checks: full inventory status, cardinality, latest-attempt reconciliation and exception list. It needs only SELECT privileges on the two views and underlying tables for reconciliation.

```sql
USE SQLManiakHealthHistory;
SELECT ServerInstance,MonitoringStatus,IsOverdue,
       LastAttemptUTC,LastCompleteUTC,MinutesSinceComplete,LastErrorText
FROM dhc.vMonitoringStatus
ORDER BY ServerInstance;
SELECT * FROM dhc.vMonitoringSummary;
```

Lab: after the previous Target 2 failure, expect `15435` to show `FAILED` **until the next successful run**, even if its Docker container has been restarted. Run the central DHC on both healthy containers, then status should show `COMPLETE` for both. `IntervalMinutes=1440` means neither should be overdue immediately after an attempt. To test overdue logic without changing production configuration, do so in a disposable copy of the repository; the shipped checks do not alter records. SQL runtime validation remains required in the user's Docker lab.
