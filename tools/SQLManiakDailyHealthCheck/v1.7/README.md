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

## NO_DATA / OVERDUE transaction-only tests

Run `11_Test-NoData-Overdue.sql` in SSMS against the **LAB repository** after `09_MonitoringStatus.sql`. It inserts three synthetic LAB inventory entries inside an explicit transaction, checks the `dhc.vMonitoringStatus` results, and **always ROLLBACKs** even when an assertion throws:

| Scenario | Expected status | IsOverdue |
|---|---|---|
| Fresh enabled registration, never checked | NO_DATA | 0 |
| Enabled registration 3h old, IntervalMinutes=60, never checked | NO_DATA | 1 |
| Disabled registration 3h old | DISABLED | 0 |

The test performs no collector runs and does not modify actual Docker endpoints. Expect three PASS verdicts and cleanup PASS; last result set should still show only your real LAB inventory. The test validates overdue detection **for never-attempted instances**, not overdue detection after a previous completed run. That scenario should be tested separately in a disposable repository before automatic scheduling. `IntervalMinutes` remains informational until we implement a due-aware runner/scheduler.

## Due-aware execution with atomic claim

Install `12_TryStartExecution.sql` on the **repository** after `04_MonitoredServers.sql`, `08_ExecutionLog.sql` and `09_MonitoringStatus.sql`. It defines `dhc.TryStartExecution`. The updated `06_Run-DHC-MonitoredServers.ps1` now uses it when `-Execute` is specified.

The procedure locks the **ServerId** for the duration of a short SQL transaction, checks the latest attempt and `IntervalMinutes`, and inserts a `RUNNING` row atomically only for eligible instances. Thus two cooperating runner processes cannot claim the same instance at the same time. A subsequent `RUNNING` blocks another claim, including `-Force`. A crashed attempt can leave `RUNNING`; it must be investigated and explicitly resolved by a DBA before resuming. This is safer than silently assuming it ended. The runner's `SKIPPED` statuses (reason `NOT_DUE` or `RUNNING`) are output-only and do **not** add history rows.

By default, a server is due immediately when no `dhc.ExecutionLog` exists; after an attempt (including FAILED) it becomes due when `StartedUTC + IntervalMinutes <= SYSUTCDATETIME()`. `-Force` overrides only the interval, not `IsEnabled` or `RUNNING`. A `-Execute` run is **due-aware**; for an immediate one-off manual test use `-Force -Execute`. `-Environment LAB` scopes the eligible targets. Preview lists `DueStatus` as of its query; actual execution always rechecks under a lock, so changes between preview and execute are handled safely.

```powershell
# Preview. Should show NOT_DUE for recently checked instances.
.\06_Run-DHC-MonitoredServers.ps1 -RepositoryConnectionString $builder.ConnectionString -Environment LAB

# Due-aware execution; immediately after a successful run, instances are SKIPPED.
.\06_Run-DHC-MonitoredServers.ps1 `
  -RepositoryConnectionString $builder.ConnectionString `
  -SqlCredentialByServer $targetCredentials `
  -Environment LAB -Execute -TrustServerCertificate

# Explicit manual override (keeps RUNNING safety).
.\06_Run-DHC-MonitoredServers.ps1 `
  -RepositoryConnectionString $builder.ConnectionString `
  -SqlCredentialByServer $targetCredentials `
  -Environment LAB -Execute -Force -TrustServerCertificate
```

```sql
-- Check that NOT_DUE attempts do not create duplicate history:
USE SQLManiakHealthHistory;
SELECT ServerInstance,COUNT_BIG(*) AS Attempts,MAX(StartedUTC) AS LastAttemptUTC
FROM dhc.ExecutionLog
WHERE ServerInstance IN (N'127.0.0.1,15434',N'127.0.0.1,15435')
GROUP BY ServerInstance;
```

No SQL Agent job or Windows Task Scheduler task has been installed yet. The next phase will integrate a central scheduler only after this lab test. Grant `EXECUTE ON OBJECT::dhc.TryStartExecution` to the dedicated repository identity when onboarding least-privilege users. The command must be launched under a properly secured identity and must not expose connection strings with passwords in task arguments.

## Concurrency Test 23 — two simultaneous claims

`13_Test-ConcurrentClaims.ps1` runs a **deterministic** two-connection concurrency test against SQL Repository. Unlike starting two collectors manually (which may complete too quickly to overlap), it opens an outer SQL transaction for claim A, which retains the `sp_getapplock` lock across the test's hold interval. On connection B it calls the **same** `dhc.TryStartExecution` asynchronously. Before A commits B must remain blocked; after commit B must return `RUNNING`, leaving only A's single `RUNNING` execution entry. Uses `-Force` in both procedure calls, so the test specifically exercises mutual exclusion rather than interval enforcement.

Run **only in the Docker LAB repository** with permission to insert/delete synthetic rows:

```powershell
.\13_Test-ConcurrentClaims.ps1 `
  -RepositoryConnectionString $builder.ConnectionString `
  -HoldMilliseconds 750
```

Expected: `Claim A: CLAIMED`, `Claim B: BLOCKED`, `Claim B: RUNNING`, `ClaimedExecutionCount=1`, `Verdict=PASS`, followed by cleanup confirmation. The test creates a uniquely named synthetic monitored server and deletes only its own ExecutionLog/MonitoredServer rows in a `finally` block, with a cleanup warning if repository cleanup is unavailable. It does **not** access real target instances or run DHC, does not change the two Docker lab inventory entries, and does not schedule anything.

This proves cooperative atomic claims under concurrency; it does not test process crash recovery, hung `RUNNING` cleanup or overall SQL Agent scheduling. A crashed runner can still leave a `RUNNING` entry requiring DBA attention.

## Stale RUNNING diagnostic (Test 24)

Deploy `14_RunningWatch.sql` on the central **LAB repository** after `08_ExecutionLog.sql`; it creates read-only `dhc.GetRunningWatch`.

```sql
USE SQLManiakHealthHistory;
-- Only suspicious runs older than one hour.
EXEC dhc.GetRunningWatch @MinAgeMinutes=60;
-- All RUNNING records, with suspected/not suspected classification.
EXEC dhc.GetRunningWatch @MinAgeMinutes=60, @IncludeRecent=1;
```

The configurable threshold is a **heuristic**, not evidence that the collector process is dead. The output includes `ExecutionId`, source, start timestamp, age, threshold, status, and classification. No historical rows are modified and no attempt is automatically unlocked, timed out or restarted. A crash may leave RUNNING indefinitely, which also blocks later `TryStartExecution` claims even with `-Force`. Investigate host process, scheduler history, repository and source activity before resolving any entry. This diagnostic does **not** install an Agent job or modify the runner.

**Test 24**: run `15_Test-RunningWatch.sql` on the LAB repository. It creates two uniquely named synthetic LAB servers and RUNNING rows inside a transaction: one 180 minutes old (suspected), one 1 minute old (not suspected). It verifies both classifications and the default stale-only filter, then always rolls back. Expect both PASS and cleanup PASS; two existing targets 15434/15435 remain unchanged.

Do not run these tests against production; only the diagnostic procedure is appropriate for production after change review.

## Stage 2 — disabled central SQL Agent job (Windows)
The Docker Linux repository (port 15433) is NOT the Windows SQL Server Agent execution host. The supplied 18_Create-SqlAgent-Job_DISABLED.sql is for a WINDOWS SQL Agent instance with PowerShell 7 and DHC scripts installed on THAT Windows host. It refuses to run until paths to pwsh.exe, wrapper script, and local private config are set; it creates a job disabled by default with a 5-minute schedule. No job is enabled by this change.

Create Windows DPAPI-protected secrets with 16_Save-DHC-SchedulerConfig.ps1 under the EXACT Windows user/machine that will execute the job. Dedicated SQL Agent service/proxy identity must export its own secrets; an interactive user cannot create DPAPI files for a different account. Protect LOCALAPPDATA folder with restricted NTFS ACL. Only nonsecret names and credential filenames are in scheduler.json; neither passwords nor full connection strings are in Git or job arguments. LAB SQL authentication is retained for staging, but replace sa with least-privilege users and trusted TLS before production.

LAB manual validation (with targetCredentials from previous session):
```powershell
$repoCredential=[PSCredential]::new('sa',(Read-Host 'LAB repository sa password' -AsSecureString))
.\16_Save-DHC-SchedulerConfig.ps1 -RepositoryServer '127.0.0.1,15433' -RepositoryCredential $repoCredential -SqlCredentialByServer $targetCredentials -TrustServerCertificate
.\17_Invoke-DHC-Scheduled.ps1 -ConfigPath "$env:LOCALAPPDATA\SQLManiakDHC\scheduler.json" -Environment LAB
.\17_Invoke-DHC-Scheduled.ps1 -ConfigPath "$env:LOCALAPPDATA\SQLManiakDHC\scheduler.json" -Environment LAB -Execute
```
Preview should show DueStatus; shortly after COMPLETE the -Execute run should produce SKIPPED/NOT_DUE and no new ExecutionLog rows. Any FAILED target makes the wrapper fail for Agent job history. This wrapper never uses -Force. Windows SQL Agent host must be able to reach repository and all sources; 127.0.0.1 addresses only work if the host runs the Docker containers locally. The actual Agent job remains disabled pending test under its service/proxy identity and security review.

## Test 28 — scheduled wrapper DUE and NOT_DUE in one LAB run

Run **only** against Docker LAB repository `127.0.0.1,15433` after Tests 25–27.
`19_Test-Scheduler-Due.ps1` prechecks both Docker LAB targets and makes sure
target 2 is currently NOT_DUE. It then temporarily changes target 1
`IntervalMinutes` from 1440 to 1, runs `17_Invoke-DHC-Scheduled.ps1 -Execute`
with existing encrypted DPAPI config, expects target 1 COMPLETE / +1
ExecutionLog row and target 2 SKIPPED NOT_DUE / +0 rows. It restores the
original 1440-minute interval in `finally` even on collection failure.
A machine crash or forced process termination can bypass `finally`: in that
case check/reset the interval manually before other operations.

```powershell
.\19_Test-Scheduler-Due.ps1 `
  -RepositoryConnectionString $builder.ConnectionString `
  -ConfigPath "$env:LOCALAPPDATA\SQLManiakDHC-v2\scheduler.json" `
  -ConnectionTimeout 3 -QueryTimeout 30
```

Expected: target 15434 COMPLETE PASS, target 15435 SKIPPED PASS,
`Test 28: PASS`, `RESTORED target 1 IntervalMinutes=1440`.
If target 2 becomes DUE before starting, test fails safely without
modifying anything. No SQL Agent job is enabled.

## Stage 3 — repository permissions and scheduler identity preflight

Deploy `20_RepositoryLeastPrivilege.sql` against the **LAB repository**.
This idempotent SQL creates **only the database role** `dhc_collector`
and object-specific `SELECT/INSERT/UPDATE/EXECUTE` grants as required by
current scripts. It does **not** create a login, grant `sysadmin`, add any
role members, or modify source SQL Server instances. The repository SQL login
must be created by an administrator and mapped to a database user; only then
add the user to role `dhc_collector` after review.

Run `21_Test-SchedulerIdentity.ps1` under the actual intended Windows
CmdExec identity **on the same host** where the DPAPI files were created:

```powershell
.\21_Test-SchedulerIdentity.ps1 `
  -ConfigPath "$env:LOCALAPPDATA\SQLManiakDHC-v2\scheduler.json" `
  -Environment LAB -CheckSqlPreview
```

Preflight verifies current Windows identity, script access, original LOCAL
DHC v1.5 source, DPAPI decryptability for repository and target credentials,
and optional read-only repository preview. Does not run DHC or enable Agent.
`-CheckSqlPreview` tests the account's actual repository access.

**Identity boundary:** The LAB DPAPI files under
`C:\Users\blad\AppData\Local` were created under that user's account.
A different SQL Agent service identity cannot decrypt them. Copying them,
changing NTFS permissions, or passing that user's profile path is NOT a
substitute for exporting fresh credentials while running under the chosen
Agent proxy/service account on the SAME host. Do not enable a job until
preflight runs successfully under that exact identity.

**Source permissions:** This role covers only central repository operations,
not source `master` diagnostics. `02_TempDB_Collect.sql` documents
`VIEW SERVER PERFORMANCE STATE` for SQL Server 2022 DMVs. Full least
privilege for the original local DHC v1.5 SQL requires auditing its exact
statements (ERRORLOG reading and other server-level diagnostics). Do not
blindly assign `sysadmin` to make an incomplete test pass. Create independent
LAB source logins only after an audit of the original SQL.

For now the existing disabled Agent template remains disabled. A CmdExec
step uses the Agent service identity unless explicitly configured with a
proper CmdExec proxy and credential. No proxy is created by these scripts.

## Test 31–33: dedicated SQL login for the Docker LAB Repository

Only after Test 29 established the `dhc_collector` role. These scripts use the
Docker LAB Repository `127.0.0.1,15433` exclusively; do **not** run them on
production instances. The existing `sa` DPAPI config in `SQLManiakDHC-v2`
remains unchanged. Source targets still use existing LAB credentials for now.

`22_New-RepositoryLabLogin.ps1`: connects with existing LAB admin connection
string, refuses to overwrite an existing login/user, generates a strong random
SQL password in memory, creates server login
`dhc_repository_collector_lab`, database user and **only** role membership
`dhc_collector`. No passwords in output, git files or command arguments.
Assign its PSCredential output to a variable, which is not persisted:

```powershell
$labRepoCredential = .\22_New-RepositoryLabLogin.ps1 `
    -RepositoryConnectionString $builder.ConnectionString
```

`23_Test-RepositoryLabLogin.ps1`: opens an actual SQL connection as that
new login, checks its effective permissions, required object rights and
absence of `sysadmin`, `db_owner`, `DELETE`, `ALTER`, `CONTROL`:

```powershell
.\23_Test-RepositoryLabLogin.ps1 -RepositoryCredential $labRepoCredential
```

Export **new** DPAPI config with repository login instead of `sa`
(leave `SQLManiakDHC-v2` untouched; target credentials still the same):

```powershell
.\16_Save-DHC-SchedulerConfig.ps1 `
    -RepositoryServer '127.0.0.1,15433' `
    -RepositoryCredential $labRepoCredential `
    -SqlCredentialByServer $targetCredentials `
    -SecretsDirectory "$env:LOCALAPPDATA\SQLManiakDHC-leastpriv" `
    -TrustServerCertificate

.\17_Invoke-DHC-Scheduled.ps1 `
    -ConfigPath "$env:LOCALAPPDATA\SQLManiakDHC-leastpriv\scheduler.json" `
    -Environment LAB
```

The preview must work without `sa`. To exercise real writes, run the
already-tested `19_Test-Scheduler-Due.ps1` as a separate test (it uses
the **existing admin** `$builder` only for temporary interval change and
history verification, while the wrapper under test authenticates with
the dedicated repository login via new DPAPI config):

```powershell
.\19_Test-Scheduler-Due.ps1 `
    -RepositoryConnectionString $builder.ConnectionString `
    -ConfigPath "$env:LOCALAPPDATA\SQLManiakDHC-leastpriv\scheduler.json" `
    -ConnectionTimeout 3 -QueryTimeout 30
```

This changes target 1 interval temporarily, restores it in finally and
expects COMPLETE +1 for 15434, SKIPPED NOT_DUE +0 for 15435. Ensure
target 2 remains NOT_DUE and no other scheduler is running.

**Safety / recovery:** the provisioner refuses to replace an existing login.
If database-user provisioning fails after CREATE LOGIN, an admin must
inspect the partial login manually; no automatic password reset. If a
PowerShell session closes before the PSCredential is exported and the login
password is lost, an administrator must deliberately rotate/reset the
dedicated LAB account, not recreate it blindly. A SQL CREATE LOGIN DDL
statement may be visible to privileged SQL monitoring/audit; deploy only
in this isolated Docker LAB. The generated credential is still tied to the
Windows account that saves it via DPAPI, not to SQL Agent's future identity.

## Test 33 failure finding: RunId column SELECT (Test 34 regression)

The first actual least-privilege execution found a missing repository grant:
`UPDATE dhc.Run ... WHERE RunId=@RunId` failed with SQL Server SELECT
permission denied on `dhc.Run`. The SQL engine must read the predicate
column to locate the row being updated; `UPDATE` permission alone is not
sufficient here. `20_RepositoryLeastPrivilege.sql` now grants
`SELECT ON OBJECT::dhc.Run (RunId)` to `dhc_collector` (column only).
This idempotent GRANT can be applied to existing DBs by rerunning SQL file,
or directly in SSMS:

```sql
USE SQLManiakHealthHistory;
GO
GRANT SELECT ON OBJECT::dhc.Run (RunId) TO dhc_collector;
GO
```

`23_Test-RepositoryLabLogin.ps1` now executes a real
`SELECT TOP (0) RunId FROM dhc.Run` as the least-privilege login,
preventing a future false-positive permission audit. Expected required
permissions check rises from **13/13 to 14/14**. The failed collection
transaction rolled back; the wrapper may still have written a FAILED
`dhc.ExecutionLog` attempt, which is expected. Retry Test 33 using the
existing DPAPI config; do not provision another login.

## Tests 34–36 — Docker LAB source least privilege

**Important source of truth:** Original `SQLManiak_Daily_Health_Check_v1_5_CSV.sql`
is deliberately kept local and not tracked in git. We cannot claim a complete
static permission inventory until Test 34 runs against the exact local file.
Older DHC revisions are not substitutes.

**34 (read-only audit):** `./24_Audit-SourceSqlPermissions.ps1` scans the
local DHC v1.5 file and prints its SHA256 and features to review. This is a
heuristic inventory; inspect actual SQL conditional paths and caught errors.

**35 (provision isolated Docker targets):** use existing admin credentials
in `$targetCredentials`, which are indexed by `127.0.0.1,15434` and
`127.0.0.1,15435`. Each target gets its own strongly generated credential.
The first lab role set is `VIEW SERVER PERFORMANCE STATE`,
`VIEW SERVER SECURITY STATE`, `VIEW ANY ERROR LOG` and
`msdb.SQLAgentReaderRole`. These are proposed diagnostic permissions,
not proof of sufficiency or minimality. No sysadmin grant. The provisioner
refuses existing logins, and failed second-target provisioning may leave
the first target created. Keep the map in memory:

```powershell
.\24_Audit-SourceSqlPermissions.ps1
$sourceLabCredentials = .\25_New-SourceLabLogins.ps1 `
  -AdminCredentialByServer $targetCredentials
```

**36 (full end-to-end test, only after reviewing Test 34):** reuses the
dedicated repository login `$labRepoCredential`, new per-target logins
`$sourceLabCredentials`, and administrator `$builder.ConnectionString`
only to prepare/verify temporary lab interval. Saves a NEW DPAPI folder;
does not touch existing v2 or repository least-privileged config.

```powershell
.\26_Test-FullLeastPrivilege.ps1 `
  -AdminRepositoryConnectionString $builder.ConnectionString `
  -RepositoryCredential $labRepoCredential `
  -SourceCredentialByServer $sourceLabCredentials
```

Target 15434 should COMPLETE +1, 15435 should SKIP NOT_DUE. Test 36
additionally checks target server permissions and scans latest `dhc.Alert`
for common denied-permission messages. SQL `TRY/CATCH` blocks in v1.5
may convert denied permissions into WARNING instead of terminating the
collector. Inspect all warnings and result sets if a section is absent:
string matching is not a complete guarantee. For target 15435, run a
separate due-aware test later to verify new credentials on that target as
well. This stage does not touch production or enable SQL Server Agent.

### Optional LAB role for SQL Trace-based autogrowth (Test 36B)

`27_Source-AutogrowthTraceRole-LAB.sql` configures a dedicated custom
server role `dhc_autogrowth_reader` granted `ALTER TRACE`, and assigns
the selected target source login. Run on **each Docker LAB target separately**,
changing `@Login` to match target 15434 or 15435. Script checks presence
and is repeatable. Do not run unchanged in production. A test connection
under the dedicated login must confirm `IsRoleMember=1`,
`CanAlterTrace=1`, `IsSysadmin=0`, and successful `SELECT` from
`sys.traces`. Then retry full DHC source collection, checking ALL
`dhc.Alert` records, especially other currently known missing permissions
(`xp_readerrorlog`, `msdb.dbo.sysschedules`,
`msdb.dbo.agent_datetime`).

Security: `ALTER TRACE` is server-wide, not a read-only privilege;
the role organizes assignment/revocation but does not reduce privilege
scope. Consider replacing the legacy SQL Trace autogrowth diagnostics
with a supported Extended Events approach as a later architectural change.

### Test 36C — read-only verification of remaining SQL source object permissions

After Test 36B verified the custom `dhc_autogrowth_reader` role on both
Docker LAB targets, run the standalone `28_Test-SourceObjectPermissions.ps1`.
It checks, **under the actual dedicated credentials** for each target,
real execution of `master.dbo.xp_readerrorlog` (filtered to a string that
should not appear), read access to `msdb.dbo.sysschedules` (TOP 0) and
execution of `msdb.dbo.agent_datetime` (scalar function).
It does not create/change objects, grant permissions or enable SQL Agent.

```powershell
.\28_Test-SourceObjectPermissions.ps1 `
  -SourceCredentialByServer $sourceLabCredentials
```

Expect six PASS results. Failures print the actual SQL exception text;
only after diagnosing them should an administrator apply object-specific
GRANT statements on each source. A PASS here does not prove that the entire
DHC v1.5 succeeds: rerun Test 36 and inspect its alerts and result sections.

### Test 36D: remaining msdb permissions

The source DHC run 72804cbf-1b2a-4d1a-a652-b732950e82a2 completed 13 result sets / 32 rows, but caught two SELECT permission denials: msdb.dbo.sysjobschedules and msdb.dbo.sysjobhistory. The stopped Agent, missing FULL for master/msdb, and ERRORLOG matches are environment/diagnostic alerts, not access denials.

Run `29_Source-MsdbAgentHistoryRole-LAB.sql` on each Docker LAB target, changing `@Login` from `dhc_source_collector_lab_1` on 15434 to `dhc_source_collector_lab_2` on 15435. Creates an idempotent custom `msdb` role with SELECT on just two tables; does not change Agent state or grant sysadmin. Test real `SELECT TOP (0)` under each dedicated source login; then rerun `26_Test-FullLeastPrivilege.ps1`. It only forces target 15434; target 15435 still needs a separate actual collection test.

### Test 36E: two additional msdb read-only table grants

The subsequent complete source run `ffc5dc75-4414-45f1-bfa4-90ac8585cd90` reported `SELECT permission was denied` on `msdb.dbo.sysjobs` (JOB SCHEDULE) and `msdb.dbo.sysjobactivity` (JOBS). `29_Source-MsdbAgentHistoryRole-LAB.sql` now also grants SELECT to the existing `dhc_agent_history_reader` role on these two tables (4 total). Re-execute that script as admin against each LAB target with its matching `@Login`. Test actual access to all four Agent tables under each dedicated source credential before retrying `26_Test-FullLeastPrivilege.ps1`; verify alert details of the new RunId. This remains a LAB-only role without any write privileges.

### Test 37 — full collection on the second Docker LAB source

Following Test 36 PASS on 15434 (`ec7e29a0-dffd-4702-9e4d-ac3705c61d9b`), execute the new LAB-only `30_Test-SecondSourceFullLeastPrivilege.ps1` from the same Windows/DPAPI identity:

```powershell
.\30_Test-SecondSourceFullLeastPrivilege.ps1 -AdminRepositoryConnectionString $builder.ConnectionString
```

It requires target 15434 to be NOT_DUE, temporarily adjusts only 15435 `IntervalMinutes` from 1440 to 1 (restored in `finally`), invokes the full-least-privilege DPAPI scheduler, verifies 15435 COMPLETE with exactly one new ExecutionLog and RunId, 15434 SKIPPED/NOT_DUE, and no recognized permission-denied alerts for 15435. Environment alerts are allowed. Requires the most recent 15435 execution to be older than one minute. Do not run concurrently with any scheduler. GitHub dashboard CI does not validate the runtime PowerShell/SQL behavior; verify locally.

### Test 38 — final read-only LAB audit (after Tests 36 and 37)

Execute `31_Test-FinalDHCDataAudit.sql` on the **repository** `127.0.0.1,15433`, database `SQLManiakHealthHistory`. It compares exact verified `RunId`s from Test 36 (`ec7e29a0-dffd-4702-9e4d-ac3705c61d9b` on 15434) and Test 37 (`c8ad74a0-d721-4124-878e-75dee31baa15` on 15435), checks persisted batches and their named sections, ExecutionLog correspondence, alerts, TempDB persistence, configuration baseline (1440 min), and current monitoring status. It makes no changes to SQL objects, data, DPAPI config, credentials, monitored instance state, or job scheduling.

Collect all nine result sets. `PASS` in the core assertions is the structural baseline; warnings about stopped Agent or missing system DB backups are environment findings, not permission denials. Different `SourceResultSets`/row totals on different hosts are **not** by themselves proof of failure: investigate section coverage before declaring completeness. GitHub CI only validates Grafana dashboards, not this T-SQL runtime audit.

### Docker LAB: healthcheck diagnostic — sql-target-2 (Test 43–44)

The Test 43 manual command with `SQLCMDPASSWORD="$MSSQL_SA_PASSWORD"` and `sqlcmd -S localhost -U sa -C -Q 'SELECT 1' -b` succeeds inside target 2, while the existing `-P`-based healthcheck remained `unhealthy` with repeating SQL error 18456 state 8. In the actual inspected healthcheck string neither a literal SA password nor the expected `$MSSQL_SA_PASSWORD` shell expansion was detected. The `sql-target-2` healthcheck now uses an environment-scoped `SQLCMDPASSWORD` assignment instead of `-P`, following the tested manual invocation. This is a targeted LAB mitigation, not proof of the precise shell-escaping cause. Password still exists in container environment (`docker inspect` environment is sensitive); never print full `docker compose config` or `docker inspect` details to logs.

Apply from this directory (after `git pull origin master`): `docker compose --profile multi-target up -d --no-deps --force-recreate sql-target-2`. This replaces ONLY the target-2 container, retaining named volume `dhc_target2_data`; **do not** run `docker compose down -v`. First ensure the lab is not concurrently collecting. Then run `docker inspect sqlmaniak-dhc-target-2 --format '{{json .State.Health}}'` locally (do not publish raw outputs that might contain secrets), and preferably use the PowerShell safe summary shown in the conversation. Verify healthy, zero failures, and cessation of newly generated SQL 18456 errors. Other services' healthcheck definitions have not been modified.
