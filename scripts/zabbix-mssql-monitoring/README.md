# SQLManiak — monitoring MSSQL w Zabbix 7.4

Rozszerzony szablon monitoringu Microsoft SQL Server oparty na oficjalnym dodatku **Zabbix Agent 2 MSSQL**, rozbudowany o własne kolektory SQLManiak, korelacje alertów, monitoring pojemności, TDE, VLF, pełny pomiar E2E oraz mechanizmy linii bazowej i wykrywania anomalii.

## Aktualna wersja

`v1.6-baseline-anomaly`

## Najważniejsze możliwości

- monitoring dostępności instancji SQL Server,
- pomiar czasu zestawienia połączenia TCP,
- CPU i presja na schedulerach SQL Server,
- względne wykorzystanie CPU z uwzględnieniem liczby schedulerów dostępnych dla SQL Server,
- CPU per baza danych,
- opóźnienia operacji I/O,
- blokady, oczekiwania na blokady i deadlocki,
- `Memory Grants Pending` i `Free List Stalls`,
- aktywne i długotrwałe transakcje,
- wykorzystanie przestrzeni danych ROWS,
- monitoring filegroupów,
- SLA backupów FULL / DIFF / LOG,
- monitoring jobów SQL Server Agent,
- stan TDE per baza danych,
- liczba VLF per baza oraz maksimum dla instancji,
- prognozowany czas do zapełnienia aktualnie zaalokowanej przestrzeni ROWS,
- pełny pomiar E2E: Zabbix Server/Proxy → Agent 2 → dodatek MSSQL → SQL Server → odpowiedź,
- średnie kroczące i sezonowa linia bazowa E2E,
- miary anomalii E2E,
- elementy oficjalnego szablonu Zabbixa: Availability Groups, mirroring, replikacja, quorum i podstawowe liczniki wydajności,
- wersjonowanie szablonu w Git z eksportem, porównaniem i importem przez Zabbix API.

## Dokumentacja

Cała dokumentacja użytkowa jest utrzymywana po polsku. Nazwy itemów, klucze Zabbixa, nazwy makr oraz nazwy obiektów SQL pozostają w oryginalnej postaci tam, gdzie są identyfikatorami technicznymi i muszą odpowiadać rzeczywistemu szablonowi.

Punkt startowy dokumentacji:

- [Spis dokumentacji](docs/README.md)
- [Pełny inwentarz szablonu](docs/01-template-inventory.md)
- [Mapowanie Excel → implementacja](docs/02-excel-mapping.md)
- [Instrukcja instalacji](docs/03-installation.md)
- [Słownik pojęć i skrótów](docs/04-slownik.md)
- [Wersjonowanie szablonu w Git](docs/05-versioning-git.md)

## Szablon v1.6

Pełny plik YAML jest przechowywany w repozytorium w postaci pięciu fragmentów `base64(gzip(...))` oraz dwóch skryptów odbudowujących. Po odbudowie suma SHA256 musi wynosić:

```text
2b47546f54ad8e9aaa78fb1ebec7b7f51ab044d137abedc6a0bf041cf500f40d
```

### Linux

```bash
cd scripts/zabbix-mssql-monitoring/templates
sh rebuild-template.sh
```

### Windows / PowerShell

```powershell
Set-Location scripts/zabbix-mssql-monitoring/templates
.\rebuild-template.ps1
```

W obu przypadkach powstaje plik:

```text
SQLManiak_MSSQL_Zabbix_7.4_matrix_v1.6_baseline_anomaly.yaml
```

Skrypty automatycznie weryfikują sumę SHA256, więc uszkodzony albo niepełny zestaw fragmentów zostanie odrzucony.

## Struktura katalogów

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

tools/
  Export-ZabbixTemplate.ps1
  Compare-ZabbixTemplate.ps1
  Import-ZabbixTemplate.ps1

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

source/
  README.md

docs/
  README.md
  01-template-inventory.md
  02-excel-mapping.md
  03-installation.md
  04-slownik.md
  05-versioning-git.md
  inventory/
  excel-mapping/
```

## Wersjonowanie szablonu

Repozytorium Git jest źródłem prawdy dla pliku YAML szablonu. Zmiany wykonane w Zabbix LAB należy wyeksportować do YAML, przejrzeć jako `git diff`, zatwierdzić przez PR i dopiero po merge importować do środowiska docelowego.

Szczegółowy proces oraz gotowe skrypty PowerShell opisuje [dokument wersjonowania](docs/05-versioning-git.md).

## Źródło wymagań

Źródłowym materiałem jest arkusz `MSSQL_alerty_Grafana_macierz_v6_complete_CPU_SQL.xlsx`. Jego identyfikację, docelową lokalizację i SHA256 opisuje [`source/README.md`](source/README.md).

Dokumentacja mapowania arkusza na implementację znajduje się w [`docs/02-excel-mapping.md`](docs/02-excel-mapping.md).

W mapowaniu używane są oznaczenia:

- ✅ — zaimplementowane,
- 🟡 — częściowo zaimplementowane lub metryka istnieje, ale docelowy trigger nie został jeszcze włączony,
- 🔁 — pierwotne rozwiązanie z arkusza zostało zastąpione innym mechanizmem,
- ⏳ — element jeszcze nie został wdrożony.

## Zasady projektowe

Nie tworzymy alertu wyłącznie dlatego, że pojedynczy licznik osiągnął wysoką wartość. Monitoring ma możliwie dobrze odróżniać objaw od rzeczywistego problemu.

Przykłady:

- blokady są interpretowane razem z lock waits, lock timeouts i średnim czasem oczekiwania,
- CPU jest normalizowane względem liczby schedulerów dostępnych dla SQL Server,
- E2E korzysta z linii bazowej i miar anomalii zamiast wyłącznie ze sztywnego progu,
- część progów dla I/O i pojemności pozostaje celowo nieaktywna do czasu zebrania rzeczywistych danych bazowych.

## Testowane środowisko

- Zabbix 7.4 uruchomiony przez Docker Compose na obrazie Alpine,
- Zabbix Agent 2 na Windows,
- nazwana instancja SQL Server `SQL3`,
- własne zapytania w katalogu:

```text
C:\Program Files\Zabbix Agent 2\Custom Queries\MSSQL
```

Dokładna konfiguracja i wszystkie kroki instalacyjne znajdują się w [instrukcji instalacji](docs/03-installation.md).
