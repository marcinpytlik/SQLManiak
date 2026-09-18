# Excel → Zabbix: alerty per instancja, per baza i CPU per baza

## Alerty per instancja

| ID | Alert z Excela | Status | Implementacja w szablonie |
|---|---|---|---|
| I-01 | Port TCP niedostępny | ✅ | Trigger `MSSQL: TCP port unavailable`. |
| I-02 | Kanał monitoringu niedostępny przy dostępnym TCP | ✅ | `MSSQL: Monitoring channel unavailable while TCP is reachable` — pierwotna semantyka ODBC została zastąpiona kanałem Agent 2 + dodatek MSSQL. |
| I-03 | Nieoczekiwany restart SQL Server | ✅ | `MSSQL: SQL Server restarted unexpectedly`. |
| I-04 | Presja CPU SQL skorelowana z presją schedulerów | 🟡 | Metryki względnego CPU, runnable tasks, `SOS_SCHEDULER_YIELD` i E2E są dostępne; skorelowany trigger CPU pressure został świadomie pozostawiony do etapu strojenia progów. |
| I-05 | Wysokie CPU innych procesów | 🟡 | `mssql.cpu.other_utilization` jest dostępne; dedykowany trigger progowy nie został jeszcze dodany. |
| I-06 | Utrzymujące się `Memory Grants Pending` | ✅ | Dostępne są triggery WARNING i HIGH dla utrzymującego się `Memory Grants Pending`. |
| I-07 | Utrzymujące się `Free List Stalls` | ✅ | Dostępne są triggery WARNING i HIGH dla utrzymujących się `Free List Stalls`. |
| I-08 | Wysokie opóźnienie odczytu I/O | 🟡 | `mssql.io.read_stall_ms` jest dostępne; alert opóźnienia pozostawiono do strojenia na podstawie rzeczywistych danych. |
| I-09 | Wysokie opóźnienie zapisu I/O | 🟡 | `mssql.io.write_stall_ms` jest dostępne; alert opóźnienia pozostawiono do strojenia na podstawie rzeczywistych danych. |
| I-10 | Blokowanie skorelowane z presją blokad | ✅ | `Blocking correlated with lock pressure` oraz `Blocking has measurable workload impact`. |
| I-11 | Wykryty deadlock / seria deadlocków | ✅ | `Deadlock detected` oraz `Deadlock burst detected`. |
| I-12 | Długotrwała transakcja | 🟡 | Metryki liczby aktywnych transakcji i maksymalnego czasu trwania są dostępne; trigger długiej transakcji nie został jeszcze aktywowany. |

## Alerty per baza danych

| ID | Alert z Excela | Status | Implementacja w szablonie |
|---|---|---|---|
| DB-01 | Stan bazy różny od ONLINE | ✅ | Dwa poziomy: HIGH dla bazy standardowej oraz DISASTER dla bazy oznaczonej jako krytyczna. |
| DB-02 | Wysokie wykorzystanie logu (%) | ✅ | Dostępne progi WARNING i HIGH dla procentowego wykorzystania logu. |
| DB-03 | Prognozowany czas do pełnego logu | 🟡 | `mssql.db.log_timeleft` jest dostępne; trzy osobne progi TTL z arkusza nie zostały jeszcze aktywowane. |
| DB-04 | Wysokie wykorzystanie zaalokowanej przestrzeni ROWS (%) | 🟡 | Dostępne są `ROWS used %` oraz `timeleft`; progi procentowe ROWS nie zostały jeszcze aktywowane. |
| DB-05 | Przekroczone SLA backupu FULL | ✅ | Dostępne progi WARNING i HIGH dla wieku backupu FULL. |
| DB-06 | Przekroczone SLA backupu DIFF | ✅ | Dostępne progi WARNING i HIGH dla wieku backupu DIFF. |
| DB-07 | Przekroczone SLA backupu LOG | ✅ | Dostępne progi WARNING i HIGH dla wieku backupu LOG z wykluczeniem baz w modelu SIMPLE. |
| DB-08 | Oczekiwany model odzyskiwania | 🟡 | Item modelu odzyskiwania jest dostępny; polityka oczekiwanego modelu i trigger nie zostały jeszcze aktywowane. |
| DB-09 | Wysokie wykorzystanie filegroupy (%) | 🟡 | Item wykorzystania filegroupy jest dostępny; trigger progowy nie został jeszcze aktywowany. |
| DB-10 | Mało wolnej zaalokowanej przestrzeni filegroupy | 🟡 | Item `filegroup free MB` jest dostępny; trigger progowy nie został jeszcze aktywowany. |
| DB-11 | Oczekiwany stan TDE | 🟡 | TDE per baza jest dostępne przez `tde_encrypted` i `tde_state`, ale polityka `TDE_REQUIRED` i odpowiadający jej trigger nie zostały jeszcze aktywowane. |
| DB-12 | Udział CPU workloadu per baza | ✅ | `mssql.db.cpu_share_pct` działa jako metryka trendowa. |
| DB-13 | Wykorzystanie pojemności CPU per baza | ✅ | `mssql.db.cpu_capacity_pct` działa jako metryka trendowa. |
| DB-14 | Anomalia CPU bazy skorelowana z presją instancji | ⏳ | Trigger anomalii CPU per baza nie został dodany; linia bazowa i anomalie w v1.6 dotyczą obecnie E2E. |

## CPU per baza danych

| ID | Metryka | Status | Implementacja |
|---|---|---|---|
| DBCPU-01 | Przyrost czasu CPU per baza | ✅ | `mssql.db.cpu_time_ms.delta`. |
| DBCPU-02 | Milisekundy CPU na sekundę per baza | ✅ | `mssql.db.cpu_ms_per_sec`. |
| DBCPU-03 | Udział bazy w CPU workloadu SQL Server | ✅ | `mssql.db.cpu_share_pct`. |
| DBCPU-04 | Wykorzystanie pojemności CPU per baza | ✅ | `mssql.db.cpu_capacity_pct`. |
| DBCPU-05 | Ranking baz według CPU | ⏳ | Ranking per baza nie został jeszcze dodany. |
| DBCPU-06 | Anomalia CPU per baza | ⏳ | Anomalia per baza nie została jeszcze dodana; mechanizm anomalii v1.6 obejmuje obecnie E2E. |

## Najważniejsze różnice względem arkusza Excel

1. **ODBC → Agent 2 + dodatek MSSQL.** Arkusz powstawał wokół `db.odbc.get[...]`; aktualna implementacja używa oficjalnego dodatku MSSQL dla Agent 2 oraz `mssql.custom.query[...]`.
2. **E2E jest pełniejsze niż w arkuszu.** `mssql.e2e.response_ms` mierzy pełny round-trip z Zabbix Server/Proxy przez `zabbix_get`, Agent 2 i dodatek MSSQL do SQL Server i z powrotem.
3. **CPU jest normalizowane względem schedulerów SQL Server.** Dodano liczbę logicznych CPU hosta, schedulery `VISIBLE ONLINE`, runnable queue, `SOS_SCHEDULER_YIELD`, względne CPU oraz CPU per baza.
4. **Monitoring pojemności został rozbudowany.** Dostępne są ROWS used/free/allocated, filegroupy, VLF per baza i maksimum na instancji oraz ROWS `timeleft()`.
5. **TDE jest monitorowane per baza.** Szablon zawiera `mssql.db.tde_encrypted` oraz `mssql.db.tde_state`.
6. **Linia bazowa i anomalie v1.6 dotyczą E2E.** Anomalia CPU per baza z arkusza pozostaje do wykonania w kolejnym etapie.
7. **Progi nie są aktywowane automatycznie wszędzie.** Dla I/O, filegroupów, ROWS i części CPU najpierw zbieramy rzeczywistą linię bazową, a dopiero potem dobieramy progi.
