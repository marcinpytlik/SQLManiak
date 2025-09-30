# 📊 SQL Server 2022 – Monitoring

## Out-of-the-box
- Extended Events: system_health (domyślnie aktywne).
- Własne XE sessions:
  - Deadlocks (xml_deadlock_report).
  - Long running queries (duration > 5s).
- Query Store – historia planów i wydajności zapytań.

## Integracja
- Telegraf agent + InfluxDB + Grafana dashboardy:
  - CPU, IO, Page Life Expectancy.
  - Wait Stats (SOS_SCHEDULER_YIELD, PAGELATCH, CXPACKET).
  - Backup/Restore events.
