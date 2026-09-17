# Mapowanie Excel → aktualny template Zabbix

**Źródło:** `MSSQL_alerty_Grafana_macierz_v6_complete_CPU_SQL(2).xlsx`  
**Target:** SQLManiak MSSQL v1.6 baseline/anomaly.

Legenda: ✅ zaimplementowane, 🟡 częściowo / metryka bez docelowego triggera, 🔁 zastąpione przez Agent 2/custom query, ⏳ niezaimplementowane.

Pełne mapowanie zostało rozdzielone dla czytelności:

- [Macierz alertów — pozycje 1–49](excel-mapping/01-macierz-01-49.md)
- [Macierz alertów — pozycje 50–82](excel-mapping/02-macierz-50-82.md)
- [Alerty per instancja / per baza / CPU per baza](excel-mapping/03-alerts-and-cpu.md)

## Stan ogólny

Większość pozycji z głównej macierzy ma odpowiednik 1:1 w template. Najważniejsze świadome różnice:

- ODBC z Excela zostało zastąpione przez **Zabbix Agent 2 MSSQL plugin** i custom queries.
- E2E zostało rozszerzone do pełnej ścieżki Zabbix Server/Proxy → Agent 2 → MSSQL plugin → SQL → return.
- CPU zostało rozszerzone o scheduler pressure, relative CPU i CPU per DB.
- Capacity zostało rozszerzone o ROWS, filegroups, VLF i predictive time-to-full.
- Baseline/anomaly v1.6 obejmuje E2E; per-DB CPU anomaly pozostaje kolejnym etapem.
- Część triggerów progowych dla I/O/capacity została celowo odłożona do zebrania baseline.
