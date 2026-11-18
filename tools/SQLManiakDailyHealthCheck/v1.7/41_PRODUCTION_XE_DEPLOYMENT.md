# SQLManiak DHC v1.7 — SQL Server 2022+ production XE deployment

**Status: production pilot candidate (SQL Server 2022+). Docker SQL Server 2022 LAB S10.3–S10.8 passed; this revision suppresses a legacy informational HISTORY notice and requires one follow-up regression run before merging. FCI and production-specific checks are still required.**
All-in-one SQL installers are T-SQL for SSMS. Scheduled collector runtime remains PowerShell 7.5+.
Do not install over the existing running collector until approved cutover.

## Deployment matrix

| File | Where | Purpose |
|---|---|---|
| `37_Install-DHC-Repository-AllInOne.sql` | Central Repository instance | Create/configure `SQLManiakHealthHistory`, SQL logins and roles. Unchanged; validated in Docker LAB. |
| `38_Configure-DHC-Source-AllInOne.sql` | Each monitored instance | `dhc_source_collector`, `VIEW SERVER PERFORMANCE STATE`, `VIEW SERVER SECURITY STATE`, `VIEW ANY ERROR LOG`, **`VIEW ANY DEFINITION`**, msdb Agent grants. |
| `39_Install-DHC-AutogrowthXE-AllInOne.sql` | Each monitored instance | Create/start `SQLManiak_Autogrowth` event_file session (automatic positive file growth only). |
| `40_Validate-DHC-Source-XE-Deployment.sql` | Each monitored instance | Read-only verification as dedicated login. |
| `03_Run-DHC-v1_7.ps1` | Collector host | Main DHC + TempDB + in-memory rewrite of original v1.5 section 12C to XE. |

**Compatibility**: SQL Server **2022+ only**. SQL Server 2016/2019 are deliberately excluded from installers 38–40; validate separately. `SQLManiak_Daily_Health_Check_v1_5_CSV.sql` is an **external local file** and is deliberately not committed here. The XE runtime rewrite expects the precise v1.5 section markers; it fails explicitly if they change.

## Confirmed integration test (18 Nov 2026)

Docker LAB source `127.0.0.1,15435` -> isolated Repository `127.0.0.1,15436`: `dhc.Run` COMPLETE, 17 DHC result sets, 56 DHC rows, 13 visible files and 13 rows in section 12C, including 4 correctly persisted XE growth events (DATA: 2 events/16MB/max 5ms; LOG: 2 events/16MB/max 66ms). No SYS.TRACES or XE permission warning. Alert details: 1 service CRITICAL and 7 configuration/backup WARNINGS. Original summary contained 1 legacy INFO HISTORY line; collector now suppresses only that informational line in central output and must be regression tested. Production Repository `15433` was not changed.

## Changes to access

The source account receives **VIEW ANY DEFINITION** for visibility into `sys.master_files`, confirmed by Docker LAB before/after test (0 -> 13 visible files). This permission exposes instance-wide object metadata. Security approval is required. The account is **not** sysadmin and should have `ALTER TRACE = 0`. The old `@GrantAlterTrace` parameter in 38 is legacy and **must remain 0** for XE deployments. Installer 38 does not revoke historic grants.

`dhc_agent_history_reader` additionally receives SELECT on `msdb.dbo.sysschedules` and EXECUTE on `msdb.dbo.agent_datetime`. Installer 38 is idempotent in the tested lab for existing principals and does not reset existing passwords.

## XE event and retention

`sqlserver.database_file_size_change` with `is_automatic = 1 AND size_change_kb > 0` records data and log autogrowth. `event_file` configured by installer 39 defaults to **32 MB x 8 rollover files** (nominal ~256 MB). It uses the SQL Server ERRORLOG directory by default; `@XelFileName` can be overridden. Confirm SQL Server service-account write access and capacity. **On an FCI, validate the path on every owner node and the retention/availability across failover.** The installer does not move files, create folders, change cluster resources, change firewall configuration or create an SQL Agent job.

Production fresh installs use `STARTUP_STATE = ON`; the existing LAB session had OFF. On an existing session installer 39 **does not silently overwrite session settings**. Verify startup mode, target path, filter, retention; manually migrate any drift with an approved change. The original XE session must be running while data is collected. Rotating XEL files cannot guarantee full 24-hour history. The DHC report deliberately uses `AVAILABLE_PARTIAL` when the XE file read succeeds, `UNAVAILABLE` otherwise; zero events under partial history **is not proof of no autogrowth**. The original DHC 12C columns and thresholds remain intact (10/30 events, 1000 ms, 10240 MB/24h), but `LastAutoGrowth` now contains **UTC** event time. Data is first materialized from XEL; then XML is parsed and 24h filtering uses UTC. Test the read overhead on large production XE files.

## Before installing

1. Obtain change approval, tested rollback, maintenance window and a backup of the central Repository. Confirm account/password secret management, SQL and OS permissions, FCI layout and available XEL disk capacity.
2. For the central Repository, configure and run **37** on the intended Repository instance only, not on every monitored instance. Review its preflight, backup, recovery, monitoring and security.
3. On **one pilot source**, make a private copy of **38**, set exact `@ExpectedServer` and a secret source password only if creating the login; set `@GrantAlterTrace = 0`. Run in SSMS. Do not commit secrets.
4. Run **39** with exact `@ExpectedServer`, approved XEL path and retention. Confirm `startup_state = 1`, `RUNNING`, predicate and actual file path. Existing sessions are not changed automatically.
5. Run **40**, verify `CanViewAnyDefinition = 1`, `CanViewPerformance = 1`, `CanAlterTrace = 0`, `IsSysadmin = 0`, full visible files, successful XEL read (may have zero events until an autogrowth occurs).
6. Run a **single** `03_Run-DHC-v1_7.ps1` invocation using source read identity and Repository insert identity into an isolated Repository; review stored `dhc.Run`, `dhc.ResultBatch`, `dhc.Alert`, `dhc.TempDBSnapshot`, ensure section `12C AUTOGROWTH EVENTS` is present and has `HistoryStatus`, verify lack of permission-error alerts.
7. Test forced controlled growth only on a **disposable pilot test database**, not on production workloads. Ensure file ID/name and times match XEL. Test restart/failover retention and effect on 24-hour reporting where applicable.
8. Only after sign-off switch scheduled collection targets one instance at a time, retaining a known-good rollback configuration. Do not mutate existing Repository collectors/schedules implicitly.

## Rollback

- **Collector**: restore prior approved `03_Run-DHC-v1_7.ps1` and collector schedule/configuration. DHC 37 Repository schema has **no schema changes** in this release.
- **XE**: first `ALTER EVENT SESSION [SQLManiak_Autogrowth] ON SERVER STATE = STOP;` on the appropriate instance **only when approved**. Do not automatically drop the session or erase XEL files; preserve diagnostic evidence.
- **Grants**: DBA may revoke `VIEW ANY DEFINITION` from dedicated source login only after verifying no other authorized workflow depends on it. Installer 38 never silently revokes grants. Restoring previous state should be coordinated with identity owner.
- **FCI**: review file path/ownership on all nodes and any remnant local XEL data.

## Known limits / gates

- Existing source v1.5 file is not part of repository; source layout compatibility must be verified in pilot.
- The central collector filters the obsolete v1.5 local-history INFO SUMMARY row, without changing source SQL. Test that `13 SUMMARY` retains all CRITICAL/WARNING rows and that `dhc.Alert` matches; the original `14 COUNTS` remains a source-side count.
- Do not reuse the Docker LAB XEL path on Windows FCI. Keep `@GrantAlterTrace=0` and verify `VIEW ANY DEFINITION` was security-approved.
- The most recent code change for INFO suppression still requires a collector rerun on the isolated test Repository before the PR is considered fully regression-tested.
- XE file loss/rollover and service restarts can leave incomplete coverage.
- `COMPLETE` is transport/run success, not proof that every diagnostic section succeeded; query `dhc.Alert` and check result-set row counts before marking deployment successful.
- Current CI validates Grafana dashboard JSON, **not actual SQL Server installation or XE execution**. A real SQL Server 2022 Docker pilot, plus Windows/FCI pilot where appropriate, is mandatory.
- SQL Server 2016/2019 require separate permission model and scripts; these installers explicitly fail.
