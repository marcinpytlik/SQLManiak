# SQLManiak DHC — Grafana MVP-04 Monitoring Reliability

The **Monitoring Reliability** dashboard is a **read-only** view of the collector/scheduler evidence held in `SQLManiakHealthHistory`. It does not report live SQL Server health: the latter is shown on Overview and Instance Details. The new dashboard does not need any schema migrations, additional SQL grants, SQL Agent jobs, collectors, or manual mutation of production history.

Dashboard: `dashboards/sqlserver/sqlmaniak-dhc-monitoring-reliability.json`
UID: `sqlmaniak-dhc-reliability`
Existing Grafana MSSQL datasource: `dhc_grafana_reader`, database `SQLManiakHealthHistory`.

## Import

1. `git pull origin master` in the SQLManiak repository.
2. In local Grafana (`http://127.0.0.1:3300`), open **Dashboards → New → Import**.
3. Import **sqlmaniak-dhc-monitoring-reliability.json** as a **new** dashboard. Do not replace Overview or Instance Details.
4. Select the same MSSQL datasource already proven by MVP-02/MVP-03. Filters: `Environment=LAB`, `Instance=All`, `Running threshold (min)=60`, time range **Last 7 days** (UTC).
5. Compare live read-only SQL checks below with displayed values.

## Interpretation

| Indicator | Source | Meaning |
| --- | --- | --- |
| Enabled instances | `dhc.vMonitoringStatus` | Enabled servers selected by environment/instance filters |
| Latest FAILED | `MonitoringStatus='FAILED'` | Latest **attempt** failed; may have an older valid diagnostic snapshot |
| Latest PARTIAL | `MonitoringStatus='PARTIAL'` | Latest attempt partially completed |
| Overdue attempts | `IsOverdue=1` | Last **attempt**, or registration when no attempt, exceeded `IntervalMinutes` |
| Never attempted | `MonitoringStatus='NO_DATA'` | No attempt has ever been logged for enabled server |
| Suspected stuck RUNNING | `MonitoringStatus='RUNNING'` + age threshold | **Suspected**, not proven orphaned; avoid automatic reset |
| Current reliability status | `dhc.vMonitoringStatus` | One prioritized status; separate `Collection` / `Overdue` columns preserve detail |
| FAILED / PARTIAL history | `dhc.ExecutionLog` | Historical attempts within selected time range; independent of current status |
| Collections by outcome | `dhc.ExecutionLog` | Hourly counts of COMPLETE/PARTIAL/FAILED |
| Open RUNNING attempts | `dhc.ExecutionLog` | All RUNNING entries, including historical stale records |
| Last successful freshness | `LastCompleteUTC` | Distinguishes freshness of **completed** collection from freshness of any attempt |

**Important:** `dhc.vMonitoringStatus.IsOverdue` measures **attempt cadence**, not freshness of successful DHC measurements. If the scheduler is down entirely, the repository's old data still allows Grafana to identify an overdue attempt, **provided Grafana and SQL Repository remain accessible**. No Grafana SQL query alone can prove that the Repository itself is unavailable; use an independent alert/uptime probe for that condition.

Values may overlap across counters: a FAILED instance can simultaneously be overdue. `RUNNING` rows older than 60 minutes require manual investigation; they are not automatically marked failed. A `PARTIAL` collection is not treated as `COMPLETE`. A `NO_DATA` instance may also become overdue after its registration interval.

## LAB checks

Execute on the DHC Repository `127.0.0.1,15433`:

```sql
USE SQLManiakHealthHistory;
GO
SELECT ServerInstance,Environment,MonitoringStatus,IsOverdue,
       LastAttemptUTC,LastCompleteUTC,MinutesSinceAttempt,MinutesSinceComplete
FROM dhc.vMonitoringStatus
WHERE IsEnabled=1 AND Environment='LAB'
ORDER BY ServerInstance;

SELECT TOP(30) ServerInstance,StartedUTC,Status,FinishedUTC,ErrorText
FROM dhc.ExecutionLog
WHERE StartedUTC>=DATEADD(DAY,-7,SYSUTCDATETIME())
ORDER BY StartedUTC DESC,ExecutionId DESC;

SELECT TOP(30) ServerInstance,StartedUTC,
       DATEDIFF_BIG(MINUTE,StartedUTC,SYSUTCDATETIME()) AS RunningAgeMin
FROM dhc.ExecutionLog
WHERE Status='RUNNING'
ORDER BY StartedUTC;
```

**Test 1 — baseline:** expected from recent LAB evidence (subject to new attempts): 2 enabled; 0 latest FAILED, 0 latest PARTIAL, 0 overdue, 0 never attempted, 0 suspected RUNNING. A historical FAILED from earlier testing should still be visible in the FAILED/PARTIAL history when the selected period includes it.

**Test 2 — FAILED:** first use existing historical failure records and the filter `Instance` to validate historical panels. To simulate a new actual failure, on LAB **only**, isolate one source Docker container using the existing tested `docker compose --profile multi-target -f compose.yaml stop sql-target-2` workflow, perform a **due-aware** collection only when eligible, then restart it and confirm recovery. Do not use `-Force` or edit `dhc.ExecutionLog` to manufacture a result. Stop the container only after verifying the exact service name with `docker compose --profile multi-target -f compose.yaml config --services` and that it is not shared with other labs. The existing DHC runner will log failure only if an attempt is actually made; `NOT_DUE` causes no change to current status.

**Test 3 — PARTIAL:** use any existing genuine PARTIAL records in the history. If none exists, leave this scenario **not tested**; do not change real server permissions or damage a working instance just to make a dashboard red. A separately isolated, disposable target can later reproduce a partial read with dedicated restricted permissions and audited cleanup.

**Test 4 — STALE:** while preserving logs, wait beyond the enabled source's normal interval (1440 minutes) with the scheduler stopped in LAB and refresh Grafana. Do not reduce `IntervalMinutes` on production or manipulate `StartedUTC` in history. This is a time-dependent integration test and is not marked PASS until the real timer crosses the threshold. The `Overdue attempts` counter should increase; the Last successful freshness panel provides a distinct reading.

**Test 5 — RUNNING:** inspect only. A RUNNING record older than the chosen threshold is **suspected** stuck, not confirmed. Do not auto-clear it or reset a scheduling lock.

**Test 6 — filtering / drilldown:** choose one target, adjust time range to Last 24 hours / Last 7 days, open **Instance** column link to Instance Details. Check that historical panels respect time range, while current-status panels always show current Repository state.

## Security and limits

- The dashboard only reads `dhc.vMonitoringStatus`, `dhc.ExecutionLog` and `dhc.MonitoredServer`, which the existing `dhc_portal_reader` can already SELECT.
- No SQL writes, no scheduler changes, no automatic remediation or new rights required.
- Grafana Query Editor users may use permitted SQL SELECT; restrict datasource/dashboard access per firm policy.
- CI validates dashboard JSON, **not** a running Grafana service. Live import, MSSQL queries, alerts and drilldowns require LAB testing.
