# Inwentarz — itemy instancji

Łącznie w szablonie: **139 itemów instancji**.

> Część 3 z 4 — kolektory SQLManiak, CPU, I/O, E2E i linia bazowa.

| Nazwa | Klucz | Sposób zbierania | Co mierzy / znaczenie |
|---|---|---|---|
| TCP connection time | `net.tcp.service.perf[tcp,{$MSSQL.HOST},{$MSSQL.PORT}]` | prosty test TCP Zabbixa | Czas zestawienia połączenia TCP do usługi SQL Server. W macierzy źródłowej przyjęto 250 ms jako WARNING i 1000 ms jako HIGH utrzymujące się przez 5 minut. |
| SQLManiak custom: CPU and scheduler raw | `mssql.custom.query["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}",sqlmaniak_cpu_health]` | Agent 2 → własne zapytanie MSSQL | Surowy kolektor topologii CPU, presji schedulerów, `SOS_SCHEDULER_YIELD` oraz podziału wykorzystania CPU hosta. |
| SQLManiak custom: I/O latency raw | `mssql.custom.query["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}",sqlmaniak_io_latency]` | Agent 2 → własne zapytanie MSSQL | Surowe skumulowane liczniki I/O używane do obliczenia opóźnienia odczytu i zapisu w ms na operację. |
| SQLManiak custom: active transactions raw | `mssql.custom.query["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}",sqlmaniak_long_transactions]` | Agent 2 → własne zapytanie MSSQL | Surowa liczba aktywnych transakcji użytkownika na instancji oraz czas najdłużej trwającej aktywnej transakcji. |
| SQLManiak custom: CPU per database raw | `mssql.custom.query["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}",sqlmaniak_db_cpu]` | Agent 2 → własne zapytanie MSSQL | Skumulowane użycie CPU przypisane do baz na podstawie plan cache. Czyszczenie lub wyrzucanie planów może obniżyć wartość skumulowaną. |
| SQLManiak custom: ROWS data space raw | `mssql.custom.query["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}",sqlmaniak_db_space]` | Agent 2 → własne zapytanie MSSQL | Zaalokowana, użyta i wolna przestrzeń plików danych typu ROWS dla każdej dostępnej bazy użytkownika. |
| SQLManiak custom: filegroups raw | `mssql.custom.query["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}",sqlmaniak_filegroups]` | Agent 2 → własne zapytanie MSSQL | Zaalokowana, użyta i wolna przestrzeń filegroupów typu ROWS w bazach użytkownika. |
| SQLManiak custom: TDE status raw | `mssql.custom.query["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}",sqlmaniak_tde_status]` | Agent 2 → własne zapytanie MSSQL | Stan szyfrowania TDE dla baz użytkownika. |
| Host logical CPU count | `mssql.cpu.host_logical_count` | item zależny od `sqlmaniak_cpu_health` | Liczba logicznych CPU hosta widoczna przez `sys.dm_os_sys_info`. |
| SQL visible online schedulers | `mssql.cpu.sql_visible_schedulers` | item zależny od `sqlmaniak_cpu_health` | Liczba schedulerów w stanie `VISIBLE ONLINE`, które SQL Server może rzeczywiście wykorzystywać. |
| Scheduler runnable tasks total | `mssql.scheduler.runnable_total` | item zależny od `sqlmaniak_cpu_health` | Łączna liczba zadań runnable oczekujących na schedulery `VISIBLE ONLINE`. |
| Runnable tasks per active scheduler | `mssql.scheduler.runnable_per_active` | item zależny od `sqlmaniak_cpu_health` | Liczba runnable tasks przypadająca na aktywny scheduler. To jeden z głównych sygnałów presji CPU na schedulerach. |
| Scheduler current tasks total | `mssql.scheduler.current_tasks_total` | item zależny od `sqlmaniak_cpu_health` | Łączna liczba bieżących zadań przypisanych do schedulerów SQL Server. |
| Scheduler active workers total | `mssql.scheduler.active_workers_total` | item zależny od `sqlmaniak_cpu_health` | Łączna liczba aktywnych workerów na schedulerach `VISIBLE ONLINE`. |
| Scheduler work queue total | `mssql.scheduler.work_queue_total` | item zależny od `sqlmaniak_cpu_health` | Łączna wielkość kolejki pracy schedulerów. |
| SOS_SCHEDULER_YIELD waiting tasks total | `mssql.waits.sos_scheduler_yield.waiting_tasks_total` | item zależny od `sqlmaniak_cpu_health` | Skumulowana liczba oczekiwań `SOS_SCHEDULER_YIELD`. |
| SOS_SCHEDULER_YIELD wait time total | `mssql.waits.sos_scheduler_yield.total_ms` | item zależny od `sqlmaniak_cpu_health` | Skumulowany czas oczekiwania `SOS_SCHEDULER_YIELD` w milisekundach. |
| SQL Server CPU utilization of host | `mssql.cpu.sql_utilization` | item zależny od `sqlmaniak_cpu_health` | Procent CPU hosta przypisany do procesu SQL Server, odczytany z Scheduler Monitor ring buffer. |
| System idle CPU | `mssql.cpu.system_idle` | item zależny od `sqlmaniak_cpu_health` | Procent bezczynnego CPU systemu (`SystemIdle`) odczytany z Scheduler Monitor ring buffer. |
| Other processes CPU utilization | `mssql.cpu.other_utilization` | item zależny od `sqlmaniak_cpu_health` | Szacowane CPU innych procesów: `100 - SystemIdle - SQL ProcessUtilization`. |
| SOS_SCHEDULER_YIELD wait time rate | `mssql.waits.sos_scheduler_yield.rate` | item zależny od `sqlmaniak_cpu_health` | Przyrost czasu oczekiwania `SOS_SCHEDULER_YIELD` w czasie. Ujemne delty po resecie licznika są sprowadzane do zera. |
| SQL Server relative CPU utilization | `mssql.cpu.sql_relative_utilization` | item obliczany z CPU hosta, liczby logicznych CPU i liczby schedulerów | Normalizuje wykorzystanie CPU SQL Server do puli schedulerów dostępnych dla instancji. Przykład: 45% CPU hosta × 24 logiczne CPU / 12 schedulerów = 90% względnego wykorzystania CPU SQL Server. |
| I/O read stall total | `mssql.io.read_stall_total_ms` | item zależny od `sqlmaniak_io_latency` | Skumulowany czas oczekiwania na odczyty I/O w milisekundach; licznik pomocniczy do obliczeń opóźnienia. |
| I/O read stall total rate | `mssql.io.read_stall_total_ms.rate` | item zależny od `sqlmaniak_io_latency` | Przyrost skumulowanego czasu oczekiwania na odczyt w przeliczeniu na sekundę. |
| I/O read operations total | `mssql.io.read_ops_total` | item zależny od `sqlmaniak_io_latency` | Skumulowana liczba operacji odczytu; licznik pomocniczy do obliczeń opóźnienia. |
| I/O read operations total rate | `mssql.io.read_ops_total.rate` | item zależny od `sqlmaniak_io_latency` | Przyrost liczby operacji odczytu w przeliczeniu na sekundę. |
| I/O write stall total | `mssql.io.write_stall_total_ms` | item zależny od `sqlmaniak_io_latency` | Skumulowany czas oczekiwania na zapisy I/O w milisekundach. |
| I/O write stall total rate | `mssql.io.write_stall_total_ms.rate` | item zależny od `sqlmaniak_io_latency` | Przyrost skumulowanego czasu oczekiwania na zapis w przeliczeniu na sekundę. |
| I/O write operations total | `mssql.io.write_ops_total` | item zależny od `sqlmaniak_io_latency` | Skumulowana liczba operacji zapisu. |
| I/O write operations total rate | `mssql.io.write_ops_total.rate` | item zależny od `sqlmaniak_io_latency` | Przyrost liczby operacji zapisu w przeliczeniu na sekundę. |
| I/O read stall (ms/op) | `mssql.io.read_stall_ms` | item obliczany z delt `sys.dm_io_virtual_file_stats` | Średnie opóźnienie odczytu w milisekundach na operację dla ostatniego interwału. |
| I/O write stall (ms/op) | `mssql.io.write_stall_ms` | item obliczany z delt `sys.dm_io_virtual_file_stats` | Średnie opóźnienie zapisu w milisekundach na operację dla ostatniego interwału. |
| Active user transactions (instance) | `mssql.long_transactions.count` | item zależny od `sqlmaniak_long_transactions` | Liczba aktywnych transakcji użytkownika na instancji. Do alertowania ważniejszy jest czas najstarszej aktywnej transakcji. |
| Oldest active transaction duration | `mssql.long_transactions.max_duration_sec` | item zależny od `sqlmaniak_long_transactions` | Maksymalny czas trwania aktywnej transakcji użytkownika, w sekundach. |
| TDE: user databases not encrypted | `mssql.tde.not_encrypted_count` | item zależny od `sqlmaniak_tde_status` | Liczba baz użytkownika bez TDE. Metryka kontekstowa do dashboardu i zgodności; globalny alert ma sens tylko przy jawnej polityce TDE_REQUIRED per baza. |
| SQLManiak custom: VLF count raw | `mssql.custom.query["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}",sqlmaniak_vlf_count]` | Agent 2 → własne zapytanie MSSQL | Liczba VLF per baza użytkownika. Kolektor używa `sys.dm_db_log_info()`, dostępnego od SQL Server 2016 SP2. |
| VLF count - maximum across user databases | `mssql.vlf_count.max` | item zależny od `sqlmaniak_vlf_count` | Maksymalna liczba VLF spośród dostępnych baz użytkownika na instancji. |
| SQLManiak E2E: raw | `sqlmaniak_mssql_e2e.sh["{HOST.CONN}","{$MSSQL.E2E.AGENT.PORT}","{$MSSQL.URI}"]` | test zewnętrzny na Zabbix Server/Proxy | Główny test pełnej ścieżki E2E. Skrypt uruchamia `zabbix_get`, odpytuje Agent 2 i wykonuje `sqlmaniak_e2e` przez dodatek MSSQL. Przy braku jawnych credentials `{$MSSQL.URI}` musi wskazywać nazwaną sesję MSSQL Agent 2. |
| SQLManiak E2E: connectivity status | `mssql.e2e.status` | item zależny od testu E2E | `1` oznacza sukces całej ścieżki Zabbix Server/Proxy → Agent 2 → dodatek MSSQL → SQL Server; `0` oznacza błąd. |
| SQLManiak E2E: response time | `mssql.e2e.response_ms` | item zależny od testu E2E | Pełny czas round-trip zmierzony po stronie Zabbix Server/Proxy wokół `zabbix_get`, w milisekundach. |
| SQLManiak E2E: zabbix_get return code | `mssql.e2e.zabbix_get_rc` | item zależny od testu E2E | Kod zakończenia `zabbix_get` użytego przez wrapper E2E. Wartość `0` oznacza poprawne wykonanie polecenia. |
| SQLManiak E2E: SQL UTC timestamp | `mssql.e2e.sql_utc` | item zależny od testu E2E | Znacznik czasu UTC zwrócony przez SQL Server podczas testu E2E. |
| SQLManiak E2E: baseline average 1h | `mssql.e2e.baseline.avg1h` | item obliczany: `avg(//mssql.e2e.response_ms,1h)` | Średnia krocząca czasu odpowiedzi E2E z ostatniej godziny. |
| SQLManiak E2E: baseline average 24h | `mssql.e2e.baseline.avg24h` | item obliczany: `avg(//mssql.e2e.response_ms,24h)` | Średnia krocząca czasu odpowiedzi E2E z ostatnich 24 godzin; krótkoterminowa linia bazowa. |
| SQLManiak E2E: baseline MAD 24h | `mssql.e2e.baseline.mad24h` | item obliczany: `mad(//mssql.e2e.response_ms,24h)` | Mediana bezwzględnych odchyleń czasu odpowiedzi E2E z 24 godzin. Odporna na pojedyncze skoki miara rozrzutu używana przy ocenie anomalii. |
