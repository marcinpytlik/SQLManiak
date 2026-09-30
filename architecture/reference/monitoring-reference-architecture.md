# Reference Architecture: SQL Server Monitoring

## Purpose

Opisać obecny model monitoringu SQL Server zbudowany wokół Zabbix Agent 2, dodatku MSSQL, custom queries oraz warstw trend/alert/baseline.

## Data flow

```text
SQL Server
    |
    | DMV / perf counters / custom queries
    v
Zabbix Agent 2 + MSSQL plugin
    |
    v
Zabbix Server / Proxy
    |
    +--> items / dependent items
    +--> LLD
    +--> calculated items
    +--> triggers
    +--> baseline / anomaly
    |
    v
Dashboards / alerts / history
```

Dodatkowe źródła:

```text
DBACentralRepository
DBA Daily Pack
Grafana dashboards
Extended Events / Query Store
```

## Architectural rules

- E2E mierzy całą ścieżkę monitoringu, nie tylko otwarty port.
- Custom queries są używane tam, gdzie standardowy plugin nie dostarcza wymaganej semantyki.
- Dependent items ograniczają liczbę niezależnych zapytań.
- LLD tworzy metryki per baza/job/replika/filegroup.
- Performance alerts są korelowane i baseline-first.
- Global waits nie są sztucznie przypisywane do baz.
- CPU per database jest traktowane jako przybliżona atrybucja/trend.

## Operational links

- [Monitoring Standard](../../standards/monitoring/)
- [Monitoring Hub](../../monitoring/)
- [Troubleshooting](../../troubleshooting/)
- [Runbooks](../../runbooks/)

## Sources

- [Zabbix MSSQL Monitoring](../../scripts/zabbix-mssql-monitoring/)
- [DBACentralRepository Performance Module](../../scripts/DBACentralRepository_v3/PERF_MODULE.md)
- [DBA Daily Pack](../../tools/DBADaillyPack/)
