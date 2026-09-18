# Excel → Zabbix: arkusz „Macierz alertów”, pozycje 1–49

**Źródło:** `MSSQL_alerty_Grafana_macierz_v6_complete_CPU_SQL(2).xlsx`  
**Szablon docelowy:** `SQLManiak_MSSQL_Zabbix_7.4_matrix_v1.6_baseline_anomaly`

> Nazwy kluczy Zabbixa i rzeczywiste nazwy itemów pozostają bez zmian, ponieważ są identyfikatorami technicznymi. Opis mapowania i nazwy kategorii są po polsku.

Legenda: ✅ zaimplementowane, 🟡 częściowo, 🔁 zastąpione innym mechanizmem, ⏳ niezaimplementowane.

| Lp. | Sekcja | Metryka z Excela | Klucz z Excela | Klasa | Status | Implementacja w szablonie | Uwagi |
|---:|---|---|---|---|---|---|---|
| 1 | Sieć | Dostępność portu TCP | `net.tcp.service[tcp,{$MSSQL.HOST},{$MSSQL.PORT}]` | ALERT | ✅ Zaimplementowane | `net.tcp.service[tcp,{$MSSQL.HOST},{$MSSQL.PORT}]` — Service's TCP port state | Klucz zgodny z arkuszem. |
| 2 | Sieć | Czas zestawienia połączenia TCP | `net.tcp.service.perf[tcp,{$MSSQL.HOST},{$MSSQL.PORT}]` | ALERT | ✅ Zaimplementowane | `net.tcp.service.perf[tcp,{$MSSQL.HOST},{$MSSQL.PORT}]` — TCP connection time | Klucz zgodny z arkuszem. |
| 3 | System | Czas działania SQL Server | `mssql.uptime` | ALERT | ✅ Zaimplementowane | `mssql.uptime` — Uptime | Klucz zgodny z arkuszem. |
| 4 | System | Wersja SQL Server | `mssql.version` | DASHBOARD | ✅ Zaimplementowane | `mssql.version["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` — Version | Agent 2 wymaga parametrów połączenia w kluczu. |
| 5 | System | Zbiorczy MSSQL Health Score 0–100 | `mssql.health.score` | DASHBOARD | ⏳ Niezaimplementowane | — | Zbiorczy Health Score pozostawiono jako koncepcję dashboardową; nie został dodany do szablonu. |
| 6 | System | Zbiorczy indeks presji I/O | `mssql.io.pressure` | TREND | ⏳ Niezaimplementowane | — | Nie dodano kompozytowego indeksu I/O. Dostępne są bezpośrednie metryki odczytu, zapisu i opóźnienia I/O. |
| 7 | System | Zbiorczy indeks efektywności blokad | `mssql.lock.efficiency` | TREND | ⏳ Niezaimplementowane | — | Nie dodano kompozytowego indeksu. Dostępne są blocking, lock waits, timeouts i deadlocki. |
| 8 | System | Zbiorczy indeks presji pamięci | `mssql.memory.pressure` | TREND | ⏳ Niezaimplementowane | — | Nie dodano kompozytowego indeksu. Dostępne są Memory Grants, Free List Stalls, PLE, Page Reads i Page Writes. |
| 9 | CPU | Wykorzystanie CPU przez SQL Server (%) | `mssql.cpu.sql_utilization` | ALERT | ✅ Zaimplementowane | `mssql.cpu.sql_utilization` — SQL Server CPU utilization of host | Klucz zgodny z arkuszem. |
| 10 | CPU | Wykorzystanie CPU przez inne procesy (%) | `mssql.cpu.other_utilization` | ALERT | ✅ Zaimplementowane | `mssql.cpu.other_utilization` — Other processes CPU utilization | Klucz zgodny z arkuszem. |
| 11 | Pamięć | Buffer cache hit ratio (%) | `mssql.buffer_cache_hit_ratio` | TREND | ✅ Zaimplementowane | `mssql.buffer_cache_hit_ratio` — Buffer cache hit ratio | Klucz zgodny z arkuszem. |
| 12 | Pamięć | Page Life Expectancy (s) | `mssql.page_life_expectancy` | TREND | ✅ Zaimplementowane | `mssql.page_life_expectancy` — Page life expectancy | Klucz zgodny z arkuszem. |
| 13 | Pamięć | Zapytania oczekujące na memory grant | `mssql.memory_grants_pending` | ALERT | ✅ Zaimplementowane | `mssql.memory_grants_pending` — Memory grants pending | Klucz zgodny z arkuszem. |
| 14 | Pamięć | Stolen Server Memory (KB) | `mssql.stolen_server_memory` | TREND | 🟡 Częściowo | `mssql.total_server_memory`, `mssql.target_server_memory`, memory grants | Brakuje dokładnego klucza `mssql.stolen_server_memory`; dostępne są inne metryki pamięci z oficjalnego szablonu. |
| 15 | Pamięć | Free List Stalls/s | `mssql.free_list_stalls_sec.rate` | ALERT | ✅ Zaimplementowane | `mssql.free_list_stalls_sec.rate` — Free list stalls per second | Klucz zgodny z arkuszem. |
| 16 | Pamięć | Lazy Writes/s | `mssql.lazy_writes_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.lazy_writes_sec.rate` — Lazy writes per second | Klucz zgodny z arkuszem. |
| 17 | Pamięć | Odczyty stron/s | `mssql.page_reads_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.page_reads_sec.rate` — Page reads per second | Klucz zgodny z arkuszem. |
| 18 | Pamięć | Zapisy stron/s | `mssql.page_writes_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.page_writes_sec.rate` — Page writes per second | Klucz zgodny z arkuszem. |
| 19 | I/O | Opóźnienie odczytu I/O (ms/op) | `mssql.io.read_stall_ms` | ALERT | ✅ Zaimplementowane | `mssql.io.read_stall_ms` — I/O read stall (ms/op) | Klucz zgodny z arkuszem. |
| 20 | I/O | Opóźnienie zapisu I/O (ms/op) | `mssql.io.write_stall_ms` | ALERT | ✅ Zaimplementowane | `mssql.io.write_stall_ms` — I/O write stall (ms/op) | Klucz zgodny z arkuszem. |
| 21 | I/O | Pełne skany/s | `mssql.full_scans_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.full_scans_sec.rate` — Full scans per second | Klucz zgodny z arkuszem. |
| 22 | I/O | Stosunek full scans do index searches | `mssql.scan_to_search` | TREND | ✅ Zaimplementowane | `mssql.scan_to_search` — Full scans to Index searches ratio | Klucz zgodny z arkuszem. |
| 23 | I/O | Page splits/s | `mssql.page_splits_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.page_splits_sec.rate` — Page splits per second | Klucz zgodny z arkuszem. |
| 24 | I/O | Tworzone work files/s | `mssql.workfiles_created_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.workfiles_created_sec.rate` — Work files created per second | Klucz zgodny z arkuszem. |
| 25 | I/O | Tworzone work tables/s | `mssql.worktables_created_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.worktables_created_sec.rate` — Work tables created per second | Klucz zgodny z arkuszem. |
| 26 | I/O | Worktables from cache ratio (%) | `mssql.worktables_from_cache_ratio` | TREND | ✅ Zaimplementowane | `mssql.worktables_from_cache_ratio` — Worktables from cache ratio | Klucz zgodny z arkuszem. |
| 27 | Blokady | Liczba zablokowanych procesów | `mssql.processes_blocked` | ALERT | ✅ Zaimplementowane | `mssql.processes_blocked` — Number of blocked processes | Klucz zgodny z arkuszem. |
| 28 | Blokady | Lock waits/s | `mssql.lock_waits_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.lock_waits_sec.rate` — Total lock requests per second that required waiting | Klucz zgodny z arkuszem. |
| 29 | Blokady | Lock timeouts/s | `mssql.lock_timeouts_sec.rate` | ALERT | ✅ Zaimplementowane | `mssql.lock_timeouts_sec.rate` — Total lock requests per second that timed out | Klucz zgodny z arkuszem. |
| 30 | Blokady | Deadlocki/s | `mssql.number_deadlocks_sec.rate` | ALERT | ✅ Zaimplementowane | `mssql.number_deadlocks_sec.rate` — Total lock requests per second that have deadlocks | Klucz zgodny z arkuszem. |
| 31 | Blokady | Łączna liczba żądań blokad/s | `mssql.lock_requests_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.lock_requests_sec.rate` — Total lock requests per second | Klucz zgodny z arkuszem. |
| 32 | Blokady | Średni czas oczekiwania na latch (ms) | `mssql.average_latch_wait_time` | TREND | ✅ Zaimplementowane | `mssql.average_latch_wait_time` — Average latch wait time | Klucz zgodny z arkuszem. |
| 33 | Blokady | Średni czas oczekiwania na blokadę (ms) | `mssql.average_wait_time` | TREND | ✅ Zaimplementowane | `mssql.average_wait_time` — Total average wait time | Klucz zgodny z arkuszem. |
| 34 | Cache | Kompilacje SQL/s | `mssql.sql_compilations_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.sql_compilations_sec.rate` — SQL compilations per second | Klucz zgodny z arkuszem. |
| 35 | Cache | Rekompilacje SQL/s | `mssql.sql_recompilations_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.sql_recompilations_sec.rate` — SQL re-compilations per second | Klucz zgodny z arkuszem. |
| 36 | Cache | Udział zapytań ad hoc (%) | `mssql.percent_of_adhoc_queries` | TREND | ✅ Zaimplementowane | `mssql.percent_of_adhoc_queries` — Percent of ad hoc queries running | Klucz zgodny z arkuszem. |
| 37 | Cache | Udział rekompilacji (%) | `mssql.percent_recompilations_to_compilations` | TREND | ✅ Zaimplementowane | `mssql.percent_recompilations_to_compilations` — Percent of Recompiled Transact-SQL Objects | Klucz zgodny z arkuszem. |
| 38 | Cache | Batch requests/s | `mssql.batch_requests_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.batch_requests_sec.rate` — Batch requests per second | Klucz zgodny z arkuszem. |
| 39 | Cache | Cache hit ratio (%) | `mssql.cache_hit_ratio` | TREND | ✅ Zaimplementowane | `mssql.cache_hit_ratio` — Cache hit ratio | Klucz zgodny z arkuszem. |
| 40 | Sesje | Liczba połączonych użytkowników | `mssql.user_connections` | TREND | ✅ Zaimplementowane | `mssql.user_connections` — Number of users connected | Klucz zgodny z arkuszem. |
| 41 | Sesje | Czas odpowiedzi zapytania end-to-end (ms) | `mssql.e2e_response_time` | ALERT | ✅ Zaimplementowane i rozszerzone | `mssql.e2e.response_ms` + `mssql.e2e.status` + linia bazowa/anomalie | Pomiar obejmuje pełny tor Zabbix Server/Proxy → Agent 2 → dodatek MSSQL → SQL Server → odpowiedź. |
| 42 | Sesje | Logowania/s | `mssql.logins_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.logins_sec.rate` — Logins per second | Klucz zgodny z arkuszem. |
| 43 | Sesje | Wylogowania/s | `mssql.logouts_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.logouts_sec.rate` — Logouts per second | Klucz zgodny z arkuszem. |
| 44 | Baza danych | Liczba aktywnych / długich transakcji | `mssql.long_transactions.count` | TREND | ✅ Zaimplementowane | `mssql.long_transactions.count` — Active user transactions (instance) | Klucz zgodny z arkuszem. |
| 45 | Baza danych | Maksymalny czas aktywnej transakcji (s) | `mssql.long_transactions.max_duration_sec` | ALERT | ✅ Zaimplementowane | `mssql.long_transactions.max_duration_sec` — Oldest active transaction duration | Klucz zgodny z arkuszem. |
| 46 | Baza danych | Deadlocki/s na instancji | `mssql.number_deadlocks_sec.rate` | DASHBOARD | ✅ Zaimplementowane | `mssql.number_deadlocks_sec.rate` | Klucz zgodny z arkuszem. |
| 47 | Baza danych | Łączna liczba błędów/s | `mssql.errors_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.errors_sec.rate` | Klucz zgodny z arkuszem. |
| 48 | Baza danych | Łączny rozmiar plików danych | `mssql.data_files_size` | DASHBOARD | ✅ Zaimplementowane | `mssql.data_files_size` | Klucz zgodny z arkuszem. |
| 49 | Baza danych | Łączny rozmiar plików logu | `mssql.log_files_size` | DASHBOARD | ✅ Zaimplementowane | `mssql.log_files_size` | Klucz zgodny z arkuszem. |
