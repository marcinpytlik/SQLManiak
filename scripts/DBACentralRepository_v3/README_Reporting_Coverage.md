# DBACentralRepository Reporting Coverage Audit

## Cel

Audyt odpowiada na pięć pytań dla każdego obszaru repozytorium:

1. Czy zbieramy dane?
2. Ile mamy tabel/snapshotów?
3. Czy istnieje warstwa `report`?
4. Czy istnieje dashboard Grafany?
5. Gdzie jest luka raportowa?

## Pliki

- `28_Reporting_Coverage_Audit.sql` — audyt warstwy SQL.
- `Get-DBACentralRepositoryReportingCoverage.ps1` — audyt dashboardów Grafany z repo.

## Obszary

- audit
- backup
- capacity
- config
- db
- ha
- job
- maintenance
- patch
- perf
- security

## Uruchomienie SQL

```sql
:r .\28_Reporting_Coverage_Audit.sql
```

lub uruchom skrypt bezpośrednio w VS Code/SSMS.

Najważniejszy wynik to `SqlCoverageStatus`:

- `NO_DATA`
- `DATA_WITHOUT_REPORTING`
- `REPORTING_EXISTS`

## Audyt Grafany

```powershell
.\Get-DBACentralRepositoryReportingCoverage.ps1 `
    -GrafanaDirectory '.\grafana'
```

Status:

- `DASHBOARD_EXISTS`
- `NO_DASHBOARD`

## Interpretacja

Najwyższy priorytet mają obszary, w których:

`DataObjectCount > 0` i `ReportViewCount + ReportProcCount = 0`

Następnie należy sprawdzić obszary, które mają reporting SQL, ale nie mają dashboardu Grafany.

## Docelowa macierz

| Area | Data | Report layer | Grafana | Action |
|---|---|---|---|---|
| perf | yes | yes | yes | maintain |
| db/schema | yes | yes | yes | maintain |
| backup | yes | ? | ? | evaluate |
| capacity | yes | ? | ? | evaluate |
| security | yes | ? | ? | evaluate |
| ha | yes | ? | ? | evaluate |
| patch | yes | ? | ? | evaluate |
| job | yes | yes | ? | evaluate |

Wartości `?` należy zastąpić wynikami skryptów audytowych.
