# SQLManiak MSSQL Monitoring for Zabbix 7.4

Rozszerzony template MSSQL oparty o oficjalny **Zabbix Agent 2 MSSQL plugin**, rozbudowany o collectory SQLManiak, korelacje alertów, capacity, TDE, VLF, pełny E2E oraz baseline/anomaly.

## Aktualna wersja

`v1.6-baseline-anomaly`

## Co jest w środku

- pełny template Zabbix 7.4,
- CPU/scheduler + relative CPU,
- CPU per baza,
- I/O latency,
- blocking / lock pressure / deadlocks,
- Memory Grants Pending / Free List Stalls,
- long/active transactions,
- DB ROWS space,
- filegroups,
- backup SLA FULL/DIFF/LOG,
- SQL Agent jobs,
- TDE per DB,
- VLF per DB i max instancji,
- ROWS time-to-full,
- full-path E2E Zabbix Server → Agent 2 → MSSQL plugin → SQL Server → return,
- E2E rolling + seasonal baseline/anomaly,
- oficjalne elementy template: AG, mirroring, replication, quorum i podstawowe performance counters.

## Dokumentacja

- [Pełny inwentarz template](docs/01-template-inventory.md)
- [Mapowanie Excel → implementacja](docs/02-excel-mapping.md)
- [Instrukcja instalacji](docs/03-installation.md)

## Template v1.6

Pełny YAML jest przechowywany w repo w postaci pięciu fragmentów `base64(gzip(...))` oraz dwóch skryptów odbudowujących. Po odbudowie SHA256 musi wynosić:

```text
2b47546f54ad8e9aaa78fb1ebec7b7f51ab044d137abedc6a0bf041cf500f40d
```

Linux:

```bash
cd scripts/zabbix-mssql-monitoring/templates
sh rebuild-template.sh
```

Windows / PowerShell:

```powershell
Set-Location scripts/zabbix-mssql-monitoring/templates
.\rebuild-template.ps1
```

W obu przypadkach powstaje:

```text
SQLManiak_MSSQL_Zabbix_7.4_matrix_v1.6_baseline_anomaly.yaml
```

Skrypty same sprawdzają SHA256, więc uszkodzony lub niepełny zestaw fragmentów zostanie odrzucony.

## Struktura

```text
templates/
  rebuild-template.sh
  rebuild-template.ps1
  packed/
    part-01.b64
    part-02.b64
    part-03.b64
    part-04.b64
    part-05.b64

custom-queries/
  sqlmaniak_cpu_health.sql
  sqlmaniak_db_cpu.sql
  sqlmaniak_db_space.sql
  sqlmaniak_filegroups.sql
  sqlmaniak_io_latency.sql
  sqlmaniak_long_transactions.sql
  sqlmaniak_tde_status.sql
  sqlmaniak_vlf_count.sql
  sqlmaniak_e2e.sql

external-scripts/
  sqlmaniak_mssql_e2e.sh

config/
  mssql_custom_queries_snippet.conf

sql/
  01_monitoring_permissions.sql

docs/
  01-template-inventory.md
  02-excel-mapping.md
  03-installation.md
  inventory/
    01-items.md
    02-discovery-prototypes.md
    03-triggers.md
    04-macros.md
```

## Źródło wymagań

Implementacja została zestawiona z arkuszem:

`MSSQL_alerty_Grafana_macierz_v6_complete_CPU_SQL(2).xlsx`

Mapowanie nie udaje zgodności tam, gdzie jej nie ma: dokument oznacza elementy `✅`, `🟡`, `🔁`, `⏳`.

## Zasada projektowa

Nie alertujemy na każdy wysoki licznik w izolacji. Przykłady:

- blocking korelujemy z lock waits / timeout / average wait,
- CPU normalizujemy do schedulerów SQL,
- E2E dostaje baseline/anomaly zamiast arbitralnego progu,
- część progów capacity/I/O pozostaje celowo nieaktywna do zebrania baseline.

## Testowane środowisko

- Zabbix 7.4 Compose / Alpine,
- Zabbix Agent 2 na Windows,
- SQL Server named instance `SQL3`,
- custom queries z katalogu `C:\Program Files\Zabbix Agent 2\Custom Queries\MSSQL`.

Szczegóły i ścieżki produkcyjne/labowe są w [docs/03-installation.md](docs/03-installation.md).
