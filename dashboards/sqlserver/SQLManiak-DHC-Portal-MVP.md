# SQLManiak DHC Portal MVP — Grafana

## Scope

Read-only dashboard for **Overview / Instances / Alerts / History** using the existing `SQLManiakHealthHistory` schema. This is **not** a real-time health monitor: source data is collected at `IntervalMinutes=1440`, while Windows scheduler checks due instances every 60 minutes. Dashboard refresh is 1 hour; it does not trigger collection.

Dashboard JSON: `dashboards/sqlserver/sqlmaniak-dhc-portal-mvp.json` (9 panels). SQL reader grants: `tools/SQLManiakDailyHealthCheck/v1.7/36_GrafanaPortalReader.sql`. Optional isolated LAB container: `tools/SQLManiakDailyHealthCheck/v1.7/grafana-compose.yaml`.

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
7. Check nine panels and test filters and time range. Cross-check with the two read-only SQL queries below. A missing time-range history is not the same as failed collection.

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
