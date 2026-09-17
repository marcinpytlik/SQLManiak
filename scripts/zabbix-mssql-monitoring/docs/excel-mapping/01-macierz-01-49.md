# Excel → Zabbix: arkusz „Macierz alertów”, pozycje 1–49

**Źródło:** `MSSQL_alerty_Grafana_macierz_v6_complete_CPU_SQL(2).xlsx`  
**Target:** `SQLManiak_MSSQL_Zabbix_7.4_matrix_v1.6_baseline_anomaly`

Legenda: ✅ zaimplementowane, 🟡 częściowo / metryka bez docelowego triggera, 🔁 zastąpione przez Agent 2/custom query, ⏳ niezaimplementowane.

| Lp. | Sekcja | Excel: metryka | Excel key | Klasa | Status | Implementacja w szablonie | Uwagi |
|---:|---|---|---|---|---|---|---|
| 1 | Network | TCP port availability | `net.tcp.service[tcp,{$MSSQL.HOST},{$MSSQL.PORT}]` | ALERT | ✅ Zaimplementowane | `net.tcp.service[tcp,{$MSSQL.HOST},{$MSSQL.PORT}]` — Service's TCP port state | Key zgodny z Excelem. |
| 2 | Network | TCP connection time | `net.tcp.service.perf[tcp,{$MSSQL.HOST},{$MSSQL.PORT}]` | ALERT | ✅ Zaimplementowane | `net.tcp.service.perf[tcp,{$MSSQL.HOST},{$MSSQL.PORT}]` — TCP connection time | Key zgodny z Excelem. |
| 3 | System | Uptime | `mssql.uptime` | ALERT | ✅ Zaimplementowane | `mssql.uptime` — Uptime | Key zgodny z Excelem. |
| 4 | System | Version | `mssql.version` | DASHBOARD | ✅ Zaimplementowane | `mssql.version["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` — Version | Agent 2 wymaga parametrów połączenia w key. |
| 5 | System | MSSQL Health Score (0-100) | `mssql.health.score` | DASHBOARD | ⏳ Niezaimplementowane | — | Health Score pozostawiony jako koncepcja dashboardowa. |
| 6 | System | MSSQL I/O Pressure Index | `mssql.io.pressure` | TREND | ⏳ Niezaimplementowane | — | Kompozytowy I/O Pressure Index nie został dodany; są surowe/rate metryki I/O. |
| 7 | System | MSSQL Lock Efficiency Index | `mssql.lock.efficiency` | TREND | ⏳ Niezaimplementowane | — | Kompozytowy Lock Efficiency Index nie został dodany; są metryki blocking/locks/deadlocks. |
| 8 | System | MSSQL Memory Pressure Index | `mssql.memory.pressure` | TREND | ⏳ Niezaimplementowane | — | Kompozytowy Memory Pressure Index nie został dodany; są grants, free list stalls, PLE, reads/writes. |
| 9 | CPU | SQL Server CPU utilization (%) | `mssql.cpu.sql_utilization` | ALERT | ✅ Zaimplementowane | `mssql.cpu.sql_utilization` — SQL Server CPU utilization of host | Key zgodny z Excelem. |
| 10 | CPU | Other processes CPU utilization (%) | `mssql.cpu.other_utilization` | ALERT | ✅ Zaimplementowane | `mssql.cpu.other_utilization` — Other processes CPU utilization | Key zgodny z Excelem. |
| 11 | Memory | Buffer cache hit ratio (%) | `mssql.buffer_cache_hit_ratio` | TREND | ✅ Zaimplementowane | `mssql.buffer_cache_hit_ratio` — Buffer cache hit ratio | Key zgodny z Excelem. |
| 12 | Memory | Page life expectancy (s) | `mssql.page_life_expectancy` | TREND | ✅ Zaimplementowane | `mssql.page_life_expectancy` — Page life expectancy | Key zgodny z Excelem. |
| 13 | Memory | Memory grants pending | `mssql.memory_grants_pending` | ALERT | ✅ Zaimplementowane | `mssql.memory_grants_pending` — Memory grants pending | Key zgodny z Excelem. |
| 14 | Memory | Stolen Server Memory (KB) | `mssql.stolen_server_memory` | TREND | 🟡 Częściowo | `mssql.total_server_memory`, `mssql.target_server_memory`, memory grants | Brak dokładnego key `mssql.stolen_server_memory`; inne metryki pamięci z oficjalnego template są dostępne. |
| 15 | Memory | Free list stalls/sec | `mssql.free_list_stalls_sec.rate` | ALERT | ✅ Zaimplementowane | `mssql.free_list_stalls_sec.rate` — Free list stalls per second | Key zgodny z Excelem. |
| 16 | Memory | Lazy writes/sec | `mssql.lazy_writes_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.lazy_writes_sec.rate` — Lazy writes per second | Key zgodny z Excelem. |
| 17 | Memory | Page reads/sec | `mssql.page_reads_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.page_reads_sec.rate` — Page reads per second | Key zgodny z Excelem. |
| 18 | Memory | Page writes/sec | `mssql.page_writes_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.page_writes_sec.rate` — Page writes per second | Key zgodny z Excelem. |
| 19 | Storage | I/O read stall (ms/op) | `mssql.io.read_stall_ms` | ALERT | ✅ Zaimplementowane | `mssql.io.read_stall_ms` — I/O read stall (ms/op) | Key zgodny z Excelem. |
| 20 | Storage | I/O write stall (ms/op) | `mssql.io.write_stall_ms` | ALERT | ✅ Zaimplementowane | `mssql.io.write_stall_ms` — I/O write stall (ms/op) | Key zgodny z Excelem. |
| 21 | Storage | Full scans/sec | `mssql.full_scans_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.full_scans_sec.rate` — Full scans per second | Key zgodny z Excelem. |
| 22 | Storage | Full scans to Index searches ratio (%) | `mssql.scan_to_search` | TREND | ✅ Zaimplementowane | `mssql.scan_to_search` — Full scans to Index searches ratio | Key zgodny z Excelem. |
| 23 | Storage | Page splits/sec | `mssql.page_splits_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.page_splits_sec.rate` — Page splits per second | Key zgodny z Excelem. |
| 24 | Storage | Work files created/sec | `mssql.workfiles_created_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.workfiles_created_sec.rate` — Work files created per second | Key zgodny z Excelem. |
| 25 | Storage | Work tables created/sec | `mssql.worktables_created_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.worktables_created_sec.rate` — Work tables created per second | Key zgodny z Excelem. |
| 26 | Storage | Worktables from cache ratio (%) | `mssql.worktables_from_cache_ratio` | TREND | ✅ Zaimplementowane | `mssql.worktables_from_cache_ratio` — Worktables from cache ratio | Key zgodny z Excelem. |
| 27 | Locks | Number of blocked processes | `mssql.processes_blocked` | ALERT | ✅ Zaimplementowane | `mssql.processes_blocked` — Number of blocked processes | Key zgodny z Excelem. |
| 28 | Locks | Lock waits/sec | `mssql.lock_waits_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.lock_waits_sec.rate` — Total lock requests per second that required waiting | Key zgodny z Excelem. |
| 29 | Locks | Lock timeouts/sec | `mssql.lock_timeouts_sec.rate` | ALERT | ✅ Zaimplementowane | `mssql.lock_timeouts_sec.rate` — Total lock requests per second that timed out | Key zgodny z Excelem. |
| 30 | Locks | Deadlocks/sec | `mssql.number_deadlocks_sec.rate` | ALERT | ✅ Zaimplementowane | `mssql.number_deadlocks_sec.rate` — Total lock requests per second that have deadlocks | Key zgodny z Excelem. |
| 31 | Locks | Total lock requests/sec | `mssql.lock_requests_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.lock_requests_sec.rate` — Total lock requests per second | Key zgodny z Excelem. |
| 32 | Locks | Average latch wait time (ms) | `mssql.average_latch_wait_time` | TREND | ✅ Zaimplementowane | `mssql.average_latch_wait_time` — Average latch wait time | Key zgodny z Excelem. |
| 33 | Locks | Total average wait time (ms) | `mssql.average_wait_time` | TREND | ✅ Zaimplementowane | `mssql.average_wait_time` — Total average wait time | Key zgodny z Excelem. |
| 34 | Cache | SQL compilations/sec | `mssql.sql_compilations_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.sql_compilations_sec.rate` — SQL compilations per second | Key zgodny z Excelem. |
| 35 | Cache | SQL re-compilations/sec | `mssql.sql_recompilations_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.sql_recompilations_sec.rate` — SQL re-compilations per second | Key zgodny z Excelem. |
| 36 | Cache | Percent of ad hoc queries (%) | `mssql.percent_of_adhoc_queries` | TREND | ✅ Zaimplementowane | `mssql.percent_of_adhoc_queries` — Percent of ad hoc queries running | Key zgodny z Excelem. |
| 37 | Cache | Percent recompilations (%) | `mssql.percent_recompilations_to_compilations` | TREND | ✅ Zaimplementowane | `mssql.percent_recompilations_to_compilations` — Percent of Recompiled Transact-SQL Objects | Key zgodny z Excelem. |
| 38 | Cache | Batch requests/sec | `mssql.batch_requests_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.batch_requests_sec.rate` — Batch requests per second | Key zgodny z Excelem. |
| 39 | Cache | Cache hit ratio (%) | `mssql.cache_hit_ratio` | TREND | ✅ Zaimplementowane | `mssql.cache_hit_ratio` — Cache hit ratio | Key zgodny z Excelem. |
| 40 | Session | Number of users connected | `mssql.user_connections` | TREND | ✅ Zaimplementowane | `mssql.user_connections` — Number of users connected | Key zgodny z Excelem. |
| 41 | Session | End-to-end query response time (ms) | `mssql.e2e_response_time` | ALERT | ✅ Zaimplementowane + rozszerzone | `mssql.e2e.response_ms` + `mssql.e2e.status` + baseline/anomaly | Pełny pomiar server→Agent2→MSSQL plugin→SQL→return. |
| 42 | Session | Logins/sec | `mssql.logins_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.logins_sec.rate` — Logins per second | Key zgodny z Excelem. |
| 43 | Session | Logouts/sec | `mssql.logouts_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.logouts_sec.rate` — Logouts per second | Key zgodny z Excelem. |
| 44 | Database | Long-running transactions count | `mssql.long_transactions.count` | TREND | ✅ Zaimplementowane | `mssql.long_transactions.count` — Active user transactions (instance) | Key zgodny z Excelem. |
| 45 | Database | Long-running transactions max duration (s) | `mssql.long_transactions.max_duration_sec` | ALERT | ✅ Zaimplementowane | `mssql.long_transactions.max_duration_sec` — Oldest active transaction duration | Key zgodny z Excelem. |
| 46 | Database | Deadlocks/sec (instancja) | `mssql.number_deadlocks_sec.rate` | DASHBOARD | ✅ Zaimplementowane | `mssql.number_deadlocks_sec.rate` | Key zgodny z Excelem. |
| 47 | Database | Total errors/sec | `mssql.errors_sec.rate` | TREND | ✅ Zaimplementowane | `mssql.errors_sec.rate` | Key zgodny z Excelem. |
| 48 | Database | Total data file size (MB) | `mssql.data_files_size` | DASHBOARD | ✅ Zaimplementowane | `mssql.data_files_size` | Key zgodny z Excelem. |
| 49 | Database | Total log file size (MB) | `mssql.log_files_size` | DASHBOARD | ✅ Zaimplementowane | `mssql.log_files_size` | Key zgodny z Excelem. |
