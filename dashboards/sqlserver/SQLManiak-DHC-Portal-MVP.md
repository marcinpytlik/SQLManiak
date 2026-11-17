# SQLManiak DHC Portal MVP — Grafana

## Scope

Read-only dashboard for **Overview / Instances / Alerts / History** using the existing `SQLManiakHealthHistory` schema. This is **not** a real-time health monitor: source data is collected at `IntervalMinutes=1440`, while Windows scheduler checks due instances every 60 minutes. Dashboard refresh is 1 hour; it does not trigger collection.

Dashboard JSON: `dashboards/sqlserver/sqlmaniak-dhc-portal-mvp.json` (11 panels, MVP-02). SQL reader grants: `tools/SQLManiakDailyHealthCheck/v1.7/36_GrafanaPortalReader.sql`. Optional isolated LAB container: `tools/SQLManiakDailyHealthCheck/v1.7/grafana-compose.yaml`.

## LAB setup

1. Ensure Docker DHC Repository `127.0.0.1,15433` is running and has `dhc.MonitoredServer`, `dhc.Run`, `dhc.Alert`, `dhc.ExecutionLog`, `dhc.vMonitoringStatus`. The previously tested 15434/15435 targets may stay as-is.
2. Create a **new dedicated SQL login** `dhc_grafana_reader` on the Repository instance (using an administrator session and a strong secret managed outside Git). Do not reuse `dhc_repository_collector_lab` and do not put a password in scripts. SQL example to run as administrator after supplying a private SQLCMD variable or using the SSMS Create Login dialog:
   `CREATE LOGIN [dhc_grafana_reader] WITH PASSWORD = <PRIVATE_STRONG_SECRET>, CHECK_POLICY=ON, CHECK_EXPIRATION=OFF;`
   The angle-bracket placeholder is *not executable SQL*. Provision the login through a secure UI / secret workflow.
3. Run `36_GrafanaPortalReader.sql` on Repository as deployment administrator. It does not create a login or reset a password, grants only the six objects required for portal queries and maps the existing login to `dhc_portal_reader`.
4. For an optional local Grafana, start the separate Compose file from the DHC v1.7 directory:
   ```powershell
   $env:DHC_GRAFANA_ADMIN_PASSWORD = Read-Host 'LAB Grafana admin password' -AsSecureString |
     ConvertFrom-SecureString -AsPlainText
   docker compose -f grafana-compose.yaml up -d
   Remove-Item Env:DHC_GRAFANA_ADMIN_PASSWORD
   ```
   Visit `http://127.0.0.1:3300`. Do not use `docker compose down -v` because it deletes the Grafana LAB volume. The Grafana image tag should be reviewed/pinned to an approved version before running.
5. In Grafana, add **Connections → Data sources → Microsoft SQL Server** with Host `host.docker.internal:15433` (Grafana running in Docker Desktop on the same Windows machine), Database `SQLManiakHealthHistory`, User `dhc_grafana_reader` and its password through the Grafana UI. Configure TLS appropriately and use **Save & Test**. If using Grafana installed natively on Windows, use host `127.0.0.1:15433`; for remote/corporate Grafana, provide an approved routable address and firewall rules rather than `127.0.0.1`.
6. **Dashboards → New → Import**, select `dashboards/sqlserver/sqlmaniak-dhc-portal-mvp.json`, and pick the MSSQL data source for the `DHC Repository` variable. Set time range to **last 7 days**, then select `Environment=LAB`, `Instance=All`. Grafana may require re-selecting the data source in the variable editor after import.
7. Check eleven panels and test filters and time range. Cross-check with the two read-only SQL queries below. A missing time-range history is not the same as failed collection.

## Validation SQL

```sql
USE SQLManiakHealthHistory;
SELECT ServerInstance,Environment,MonitoringStatus,IsOverdue,LastAttemptUTC,LastCompleteUTC
FROM dhc.vMonitoringStatus ORDER BY ServerInstance;

SELECT TOP (20) StartedUTC,ServerInstance,Status,RowsStored
FROM dhc.ExecutionLog ORDER BY StartedUTC DESC;
```

Dashboard's "CRITICAL alerts (latest runs)" and "Alerts · latest collected run" are derived from the latest COMPLETE/PARTIAL `dhc.Run` for each enabled instance. Historical alerts and collection history respond to the Grafana time picker. Unlike the summary, "current alerts" reflects the last collected snapshot and can persist until the next DHC run; it is **not** a real-time fault indicator. Current COMPLETE is a last-attempt/interval status rather than a guarantee that no WARNING/CRITICAL exists. The portal does not provide acknowledgement, remediation or configuration changes.

## Security

The reader role grants SELECT on `dhc.MonitoredServer`, `dhc.ExecutionLog`, `dhc.Run`, `dhc.Alert`, `dhc.vMonitoringStatus` and `dhc.vMonitoringSummary` only. It does **not** grant access to `dhc.ResultBatch` raw JSON or credential tables. Users with Grafana Query Editor access can execute additional permitted read queries, so restrict datasource query-edit permissions and visibility. Alerts and error details may contain sensitive server information.

**Validation status:** JSON syntax and SQL schema references checked against repository sources; live import, Grafana MSSQL connection and visual panels require an interactive test on the user's LAB. Existing GitHub Grafana CI may cover JSON validation but not runtime query results.

## MVP-02: separate collection state from SQL health (LAB)

**Collection · on schedule** is the number of enabled instances whose last attempt is `COMPLETE` and `IsOverdue=0`. **Collection · needs attention** counts FAILED/PARTIAL/RUNNING/NO_DATA and overdue attempts. These describe delivery, not SQL Server service/database health.

**SQL health** uses only the latest `dhc.Run` with status `COMPLETE` or `PARTIAL` for each enabled instance:
- `CRITICAL`: at least one CRITICAL alert in that diagnostic snapshot
- `WARNING`: WARNING alert(s) and no CRITICAL
- `OK`: that snapshot has neither severity
- `STALE`: the instance is overdue, even if an older snapshot contains alerts
- `NO_DATA`: no COMPLETE/PARTIAL diagnostic snapshot exists

The status is **point-in-time evidence, not real-time health**. Collection attempt failures do not erase the last diagnostic snapshot; inspect collection status and the timestamp together. `PARTIAL` snapshots may not contain a complete set of checks, so `OK` is not a guarantee of healthy SQL Server.

The Instances table includes separately colored `Collection`, `Overdue` and `SQL health`, plus critical/warning counts from the latest available snapshot. Filter to Environment=LAB and Instance=All after reimport. Expected from the observed LAB screenshot (subject to data changes): enabled=2, collection on schedule=2, collection issues=0, SQL health CRITICAL=2, WARNING=0, STALE/NO DATA=0. SQL Server Agent stopped in both Linux Docker targets is the source of two critical service alerts; it is not evidence that the collector failed.

### Verification SQL

Execute below on the Repository and compare with the Grafana Instances panel after import:

```sql
USE SQLManiakHealthHistory;
GO
SELECT s.ServerInstance,s.MonitoringStatus AS Collection,s.IsOverdue,
 CASE WHEN r.RunId IS NULL THEN 'NO_DATA'
      WHEN s.IsOverdue=1 THEN 'STALE'
      WHEN ISNULL(a.CriticalCount,0)>0 THEN 'CRITICAL'
      WHEN ISNULL(a.WarningCount,0)>0 THEN 'WARNING'
      ELSE 'OK' END AS SQLHealth,
 ISNULL(a.CriticalCount,0) AS CriticalAlerts,
 ISNULL(a.WarningCount,0) AS WarningAlerts,
 r.StartedUTC AS DiagnosticSnapshotUTC
FROM dhc.vMonitoringStatus s
OUTER APPLY (
 SELECT TOP(1) RunId,StartedUTC
 FROM dhc.Run
 WHERE ServerInstance=s.ServerInstance AND Status IN ('COMPLETE','PARTIAL')
 ORDER BY StartedUTC DESC,RunId DESC
) r
OUTER APPLY (
 SELECT SUM(CASE WHEN Severity='CRITICAL' THEN 1 ELSE 0 END) CriticalCount,
        SUM(CASE WHEN Severity='WARNING' THEN 1 ELSE 0 END) WarningCount
 FROM dhc.Alert WHERE RunId=r.RunId
) a
WHERE s.IsEnabled=1 AND s.Environment='LAB'
ORDER BY s.ServerInstance;
```

Grafana dashboard JSON and the SQL above are source-checked, but live Grafana import and SQL results still need to be confirmed on the running LAB. Reimport the same UID `sqlmaniak-dhc-mvp`, replacing the older dashboard.

## MVP-03: per-instance dashboard (LAB)

Import the second dashboard `dashboards/sqlserver/sqlmaniak-dhc-instance-details.json` using the **same MSSQL data source** as the overview. UID: `sqlmaniak-dhc-instance`. It is separate from `sqlmaniak-dhc-mvp`; do not overwrite Overview with the new JSON.

**Required database permissions:** rerun the updated `36_GrafanaPortalReader.sql` as a Repository administrator. It grants only `SELECT` on `dhc.vTempDBTrend`, `dhc.TempDBSnapshot` and `dhc.TempDBFile` in addition to existing Portal permissions. No access to `dhc.ResultBatch`, `dhc.TempDBSession` or write rights is added.

**MVP-03 panel list:** SQL diagnostic health; collection state/freshness; latest diagnostic alerts; latest TempDB snapshot; TempDB data used vs version store; TempDB log used vs allocated; TempDB file/growth inventory; execution history; alert history.

**Usage:** first import/reimport Overview `sqlmaniak-dhc-portal-mvp.json` (version 4), then import `sqlmaniak-dhc-instance-details.json`. In Overview → Instances, use the **Instance** column data link `Open instance details` to open the second dashboard with the selected endpoint; or open Instance Details directly and select a single instance from its dropdown. Dashboard `Instance` is a *single-value* variable with `All` disabled to prevent accidental multi-instance data mixing. Choose a target manually if Grafana imports the dashboard without a default value. The default time range is last 7 days (UTC). The **latest** snapshot/alerts do not depend on the time picker; history/trend panels do. Data points reflect daily DHC sampling rather than continuous measurements.

**LAB validation (127.0.0.1,15434 and 15435):**

1. Verify the 36 script's effective permissions via a connection as `dhc_grafana_reader`:
   ```sql
   USE SQLManiakHealthHistory;
   SELECT TOP(1) ServerInstance,StartedUTC,VersionStoreMB FROM dhc.vTempDBTrend;
   SELECT TOP(1) RunId,FileId,NextGrowthWillFit FROM dhc.TempDBFile;
   ```
2. Choose `127.0.0.1,15434`; compare the top status to `dhc.vMonitoringStatus`, and latest diagnostic alerts to Overview's filtered alerts. Verify TempDB latest snapshot if present. Compare with `127.0.0.1,15435`; the data must not mix.
3. For **Last 7 days**, ensure collection history and alert history display the expected timestamps. Change to **Last 24 hours** and verify only history/trend panels change; latest alerts and latest TempDB remain last available.
4. Click Overview → Instance and verify navigation preserves datasource, instance and time range. This is a UI behavior to confirm on the running LAB, not guaranteed by JSON validation.
5. Confirm a missing TempDB snapshot results in no rows on TempDB panels rather than a false zero metric.

**Read-only design:** every query targets Repository only. `TempDBFile` shows the last snapshot with TempDB data and file growth assessments, **not** live SQL Server file state. SQL health `OK` based on a partial diagnostic snapshot is not a guarantee of a healthy instance.

**Release status:** GitHub dashboard CI checks JSON syntax/structure; Grafana rendering, datasource links, SQL query execution and inter-panel navigation require LAB verification after import.

### MVP-03 LAB fix: SQL health Stat panel

Observed on 2026-11-17: source and TempDB panels show live repository rows after granting `dhc_portal_reader` SELECT, while string-valued SQL health Stat renders `No data`. Version 2 of Instance Details returns a numeric status code from SQL: 0=OK, 1=WARNING, 2=CRITICAL, 3=STALE, 4=NO_DATA, then uses Grafana value mappings to show colored text. This is only a dashboard update; no DHC collector/schema changes. For LAB target `127.0.0.1,15435`, the latest diagnostic snapshot had 1 CRITICAL and 3 WARNING alerts, so expected value is `CRITICAL` (2). Re-import with the same UID; inspect the Stat query if it still renders No data.

## MVP-04 Monitoring Reliability

The dedicated 11-panel collector health dashboard is `dashboards/sqlserver/sqlmaniak-dhc-monitoring-reliability.json`. It uses existing read-only Repository grants, distinguishes overdue attempts from outdated successful collections, and shows FAILED/PARTIAL history and suspected RUNNING entries. For import and safe LAB reliability checks, see [Monitoring Reliability](SQLManiak-DHC-Monitoring-Reliability.md). Reimport Overview (same UID) to enable its top navigation link to Monitoring Reliability.
