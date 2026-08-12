# DBACentralRepository v3 – Grafana

Grafana staje się warstwą prezentacji **żywych danych technicznych**. Confluence może pozostać dla dokumentacji opisowej i procedur, ale dashboardy nie wymagają eksportu HTML ani publikowania stron.

## Architektura

```text
SQL Server instances
        ↓
Collectors PowerShell
        ↓
DBACentralRepository
        ↓
report.vGrafana*
        ↓
Grafana (Microsoft SQL Server datasource)
```

## Widoki

- `report.vGrafanaInstances`
- `report.vGrafanaDatabases`
- `report.vGrafanaJobs`
- `report.vGrafanaBackupStatus`
- `report.vGrafanaPatchStatus`
- `report.vGrafanaPerformanceTimeSeries`
- `report.vGrafanaFileIoTimeSeries`
- `report.vGrafanaPerformanceLatest`

## Dashboardy

Katalog `grafana/` zawiera dashboardy startowe:

1. `DBACentralRepository-Fleet-Overview.json`
2. `DBACentralRepository-Instance-Workload.json`
3. `DBACentralRepository-Database-Workload.json`
4. `DBACentralRepository-Operations.json`

Podczas importu wskaż datasource Microsoft SQL Server połączony z bazą `DBACentralRepository`.

## Zalecane konto datasource

Grafana potrzebuje tylko odczytu. Przykład:

```sql
USE DBACentralRepository;
CREATE USER [grafana_reader] FOR LOGIN [grafana_reader];
ALTER ROLE db_datareader ADD MEMBER [grafana_reader];
```

Jeśli polityka bezpieczeństwa wymaga minimalizacji dostępu, zamiast `db_datareader` można nadać `SELECT` wyłącznie na schemat `report`:

```sql
GRANT SELECT ON SCHEMA::report TO [grafana_reader];
```

## Zmienne dashboardów

Instancje:

```sql
SELECT ServerInstance AS __text, InstanceId AS __value
FROM report.vGrafanaInstances
ORDER BY EnvironmentCode, ServerInstance;
```

Bazy:

```sql
SELECT DISTINCT DatabaseName AS __text, DatabaseName AS __value
FROM report.vGrafanaDatabases
WHERE InstanceId = $InstanceId
ORDER BY DatabaseName;
```

## Performance

`perf` przechowuje liczniki narastające. Dla prawdziwego zużycia w przedziale czasu korzystaj z procedury:

```sql
EXEC perf.usp_GetDatabaseLoadRanking
    @InstanceId = 1,
    @From = DATEADD(hour,-1,SYSDATETIME()),
    @To = SYSDATETIME(),
    @Top = 20;
```

W dashboardach time-series można prezentować wartości surowe albo liczyć delty w zapytaniu Grafany. Do rankingu zalecane są procedury `perf.usp_Get...`.
