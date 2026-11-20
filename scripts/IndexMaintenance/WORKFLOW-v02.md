# SQLManiak Index Maintenance — v0.2 workflow (LAB / PILOT)

## Status

Implemented in source, **not yet executed against user's SQL Server instances**.
The old central database has 10 tables and 6 procedures verified by the user. v0.2 migrations, PS scripts and integration test are **unverified in SQL Server runtime**.

## Five stages

1. **Collect:** run `collector/Invoke-CentralAudit.ps1` against enabled endpoints (FCI VNNs). Results travel through `im.RemoteIndexStage`, `im.IndexAssessment` and `im.AuditRun`. Review `tests/Integration-Smoke.sql` and `005_AuditReports.sql`. This is a read-heavy DMV audit, not a safe daily lightweight inventory. Important: existing collector uses LIMITED + bounded SAMPLED; run off-peak.
2. **Historical evidence:** `011_HistoryAndTrends.sql` introduces `im.IndexHistory` and `im.IndexHistoryDaily`; `import/Import-IndexHistoryCsv.ps1` imports CSV with headers DateTime,Server,Database,Table,IndexName,AvgFragmentationPot,TotalPageCount,PartitionCount. `014_HistoryInsights.sql` reports volatility. Historical data are aggregated and lack per-partition IDs, density and access metrics: do not automatically turn them into execution permissions.
3. **Classify:** `008_ClassifyRemote.sql` currently classifies measured partitions using size, fragmentation and density. This is **preliminary**; no Query Store or usage-stats analysis yet. Large partitions or low density are `REVIEW`, not automatic maintenance.
4. **Plan:** `012_PlanQueue.sql` creates `im.MaintenanceQueue`. Procedure `im.ProposeMaintenance @AuditRunId` builds proposals. `im.ApproveMaintenance` requires explicit DBA approval.
5. **Execute:** `013_ExecutionControl.sql` serializes claims per cluster, checks enabled targets and audit freshness. `executor/Invoke-ApprovedMaintenance.ps1` defaults to dry-run. Explicit `-Execute -ConfirmExecution` runs only an approved item with metadata revalidation. `REBUILD` requests ONLINE + low-priority wait and fails rather than falling back to offline operations. Results are recorded in `im.MaintenanceQueue`.

## Prerequisites and installation

- SQL Server 2022+, Windows PowerShell 7.5 (`pwsh`), Microsoft.Data.SqlClient assembly loadable via `Add-Type`.
- Test with **one small noncritical database first**, then two instances (including same WSFC), then FCI failover.
- Existing SQL scripts 001–010 first; apply 011, 012, 013, 014 to central repository in order.
- Current repo uses Windows integrated auth and TLS verification by default. Do not place passwords in files. Grant minimum SQL rights, including DMV view rights on targets and restricted central database permissions.
- Allow I/O/log headroom, coordinate with existing backup windows (never disable backups as default).
- Isolate tests from production and review all procedure permissions. A signed module or least-privileged execution role remains future hardening.

## Test A — collectors on two instances

1. In LAB register two FCI VNNs via `im.RegisterTarget`; enable only one test database per instance, one endpoint each.
2. Run `collector/Invoke-CentralAudit.ps1 -RepositoryServer 'CENTRAL-VNN'`.
3. Confirm exactly two `Completed` audit runs and nonzero `im.IndexAssessment` rows, with correct `InstanceName`, `DatabaseName`, `ObjectId`, partition number and classification. If test table indexes have fewer than 1000 pages, adjust `AuditPolicy.MinPagesForReview` lower **only in lab**.
4. Run controller again; confirm new audit IDs and history retained.
5. Simulate target disconnect/failover in LAB. Expect `Failed` run after error; repeated invocation after recovery should create a *new* run. No in-flight resume. Lease expiration and controller recovery need specific test, and long audits exceed default lease without heartbeat.
6. Verify one-heavy-audit-per-cluster lock with two simultaneous controllers (LAB only). Current connector is sequential; `MaxConcurrentHeavyAudits` above one is not implemented.

## Test B — synthetic classification and queue

Run `tests/Workflow-Regression.sql` **on isolated LAB central repository**. It inserts synthetic rows under a transaction, asserts the classifications and queue statuses and rolls back. It issues **no ALTER INDEX**. Observe `PASS`; failing assertion throws 5120x.

## Test C — history import

First export 50–100 rows from historical source to CSV. Use invariant decimal dot and ISO timestamps. Example:

```powershell
pwsh -File .\import\Import-IndexHistoryCsv.ps1 -RepositoryServer 'CENTRAL-VNN' -Path '.\history-sample.csv' -SourceName 'Legacy2026' -WhatIf
pwsh -File .\import\Import-IndexHistoryCsv.ps1 -RepositoryServer 'CENTRAL-VNN' -Path '.\history-sample.csv' -SourceName 'Legacy2026'
```

Verify counts in `im.IndexHistory` and output `014_HistoryInsights.sql`. **Importer currently has no deduplication**; run one import per exported source batch. Do not assume changing fragmentation proves REBUILD.

## Test D — queue proposal and dry-run

```sql
USE SQLManiakIndexMaintenance;
EXEC im.ProposeMaintenance @AuditRunId = 123; -- change to a completed LAB audit
SELECT * FROM im.PendingMaintenance ORDER BY QueueId;
-- Choose a safe test candidate and explicitly approve:
EXEC im.ApproveMaintenance @QueueId = 1, @ApprovalName = N'LAB-DBA';
```

```powershell
pwsh -File .\executor\Invoke-ApprovedMaintenance.ps1 -RepositoryServer 'CENTRAL-VNN' -QueueId 1
```

Preview must not alter indexes or change queue status. Only after verifying a noncritical test target and available ONLINE support:

```powershell
pwsh -File .\executor\Invoke-ApprovedMaintenance.ps1 -RepositoryServer 'CENTRAL-VNN' -QueueId 1 -Execute -ConfirmExecution
```

The live execution path **has not yet been validated**. Never use -Execute in production before SQL laboratory tests and code review.

## Safety and known gaps

- No automatic scheduler; no continuous discovery, no daily lightweight metadata collector.
- No auto-approval; no fully automatic production maintenance.
- No backup jobs stopped or modified.
- Rebuild not supported for every index/edition/type; error is recorded rather than offline fallback.
- No transaction log space forecasts, Query Store-based prioritization, fillfactor tuning or history-driven automatic approval.
- Queue items stuck in Running after executor crash must be handled **manually**; do not replay blindly.
- No heartbeat for long-running audit leases. Current audit may overrun lease and allow competing work unless scheduled windows and leases are carefully controlled.
- No automatic cleanup/retention for staging and history yet.
- Use change-control, restore-tested backups and a controlled maintenance window.

## Acceptance criteria before production

- 2+ instances / 2+ clusters pass audit → staging → assessment, including one FCI failover.
- Safe, repeatable history ingestion; duplicates and schema name ambiguity addressed.
- Classification manually validated on known indexes, index coverage limits documented.
- Queue duplicate prevention, manual approval, token-guarded completion verified.
- Dry-run and actual execution pass on test indexes; no offline fallback; archive logs and timings.
- Recovery, cancellation and concurrency handling exercised under injected failures.
