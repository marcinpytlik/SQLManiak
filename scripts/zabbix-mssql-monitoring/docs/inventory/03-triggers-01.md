# Inventory — triggery i trigger prototypes

Łącznie: **76**.

| Źródło | Trigger | Severity | Warunek | Opis |
|---|---|---|---|---|

> Część 1.

| item: Total average wait time | MSSQL: Total average wait time for locks is high | `WARNING` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.average_wait_time,5m)>{$MSSQL.AVERAGE_WAIT_TIME.MAX}` | An average wait time longer than 500 ms may indicate excessive blocking. This value should generally correlate to Lock Waits/sec. |
| item: Buffer cache hit ratio | MSSQL: Percentage of the buffer cache efficiency is low | `HIGH` | `max(/SQLManiak MSSQL by Zabbix agent 2/mssql.buffer_cache_hit_ratio,5m)<{$MSSQL.BUFFER_CACHE_RATIO.MIN.CRIT}` | Too low buffer cache hit ratio. |
| item: Buffer cache hit ratio | MSSQL: Percentage of the buffer cache efficiency is low | `WARNING` | `max(/SQLManiak MSSQL by Zabbix agent 2/mssql.buffer_cache_hit_ratio,5m)<{$MSSQL.BUFFER_CACHE_RATIO.MIN.WARN}` | Low buffer cache hit ratio. |
| item: Free list stalls per second | MSSQL: Number of rps waiting for a free page is high | `WARNING` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.free_list_stalls_sec.rate,5m)>{$MSSQL.FREE_LIST_STALLS.MAX}` | Requests wait for a free page. |
| item: Free list stalls per second | MSSQL: Free List Stalls persistent - high | `HIGH` | `avg(/SQLManiak MSSQL by Zabbix agent 2/mssql.free_list_stalls_sec.rate,{$MSSQL.FREELIST.CRIT.TIME})>0` | Sustained free-list stalls; correlate with Memory Grants, PLE, Lazy Writes and Page Reads. |
| item: Free list stalls per second | MSSQL: Free List Stalls persistent - warning | `WARNING` | `avg(/SQLManiak MSSQL by Zabbix agent 2/mssql.free_list_stalls_sec.rate,{$MSSQL.FREELIST.WARN.TIME})>0` | Persistent memory pressure signal. |
| item: Lazy writes per second | MSSQL: Number of buffers written per second by the lazy writer is high | `WARNING` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.lazy_writes_sec.rate,5m)>{$MSSQL.LAZY_WRITES.MAX}` | Lazy writer activity above threshold. |
| item: Total lock requests per second | MSSQL: Total number of locks per second is high | `WARNING` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.lock_requests_sec.rate,5m)>{$MSSQL.LOCK_REQUESTS.MAX}` | High lock request rate. |
| item: Total lock requests per second that timed out | MSSQL: Total lock requests per second that timed out is high | `WARNING` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.lock_timeouts_sec.rate,5m)>{$MSSQL.LOCK_TIMEOUTS.MAX}` | High lock timeout rate. |
| item: Total lock requests per second that required waiting | MSSQL: Some blocking is occurring for 5m | `AVERAGE` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.lock_waits_sec.rate,5m)>0` | Values above zero indicate blocking. |
| item: Total lock requests per second that required waiting | MSSQL: Blocking has measurable workload impact | `HIGH` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.processes_blocked,5m)>0 and (max(/SQLManiak MSSQL by Zabbix agent 2/mssql.lock_timeouts_sec.rate,5m)>0 or avg(/SQLManiak MSSQL by Zabbix agent 2/mssql.average_wait_time,5m)>{$MSSQL.AVGWAIT.CRIT})` | Blocking with lock timeouts or high average wait time. |
| item: Total lock requests per second that required waiting | MSSQL: Blocking correlated with lock pressure | `WARNING` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.processes_blocked,2m)>0 and avg(/SQLManiak MSSQL by Zabbix agent 2/mssql.lock_waits_sec.rate,2m)>{$MSSQL.LOCKWAITS.WARN}` | Blocking plus elevated lock-wait pressure. |
| item: Memory grants pending | MSSQL: Memory Grants Pending persistent - high | `HIGH` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.memory_grants_pending,{$MSSQL.MEMGRANT.CRIT.TIME})>0` | Sustained workspace-memory pressure. |
| item: Memory grants pending | MSSQL: Memory Grants Pending persistent - warning | `WARNING` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.memory_grants_pending,{$MSSQL.MEMGRANT.WARN.TIME})>0` | Sustained workspace-memory pressure. |
| item: Total lock requests per second that have deadlocks | MSSQL: Number of deadlocks is high | `AVERAGE` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.number_deadlocks_sec.rate,5m)>{$MSSQL.DEADLOCKS.MAX}` | Too many deadlocks currently. |
| item: Total lock requests per second that have deadlocks | MSSQL: Deadlock burst detected | `HIGH` | `sum(/SQLManiak MSSQL by Zabbix agent 2/mssql.number_deadlocks_sec.rate,10m)>={$MSSQL.DEADLOCK.CRIT.COUNT}` | Multiple deadlocks in a 10-minute window. |
| item: Total lock requests per second that have deadlocks | MSSQL: Deadlock detected | `WARNING` | `sum(/SQLManiak MSSQL by Zabbix agent 2/mssql.number_deadlocks_sec.rate,10m)>0` | At least one deadlock in the last 10 minutes. |
| item: Page life expectancy | MSSQL: Page life expectancy is low | `HIGH` | `max(/SQLManiak MSSQL by Zabbix agent 2/mssql.page_life_expectancy,15m)<{$MSSQL.PAGE_LIFE_EXPECTANCY.MIN}` | PLE below threshold. |
| item: Page reads per second | MSSQL: Number of physical database page reads per second is high | `WARNING` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.page_reads_sec.rate,5m)>{$MSSQL.PAGE_READS.MAX}` | Physical page reads are high. |
| item: Page writes per second | MSSQL: Number of physical database page writes per second is high | `WARNING` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.page_writes_sec.rate,5m)>{$MSSQL.PAGE_WRITES.MAX}` | Physical page writes are high. |
| item: Percent of ad hoc queries running | MSSQL: Percent of ad hoc queries running is high | `WARNING` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.percent_of_adhoc_queries,15m) > {$MSSQL.PERCENT_COMPILATIONS.MAX}` | High compilation-to-batch ratio. |
| item: Percent of Recompiled Transact-SQL Objects | MSSQL: Percent of times statement recompiles is high | `WARNING` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.percent_recompilations_to_compilations,15m) > {$MSSQL.PERCENT_RECOMPILATIONS.MAX}` | Recompilation ratio is high. |
| item: Full scans to Index searches ratio | MSSQL: Number of index and table scans exceeds index searches in the last 15m | `WARNING` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.scan_to_search,15m) > 0.001` | Too many full scans relative to index searches for OLTP. |
| item: Uptime | MSSQL: Failed to fetch info data | `INFO` | `nodata(/SQLManiak MSSQL by Zabbix agent 2/mssql.uptime,30m)=1` | No monitoring data for 30 minutes. |
| item: Uptime | MSSQL: Service has been restarted | `INFO` | `last(/SQLManiak MSSQL by Zabbix agent 2/mssql.uptime)<10m` | Uptime below 10 minutes. |
| item: Uptime | MSSQL: SQL Server restarted unexpectedly | `HIGH` | `last(/SQLManiak MSSQL by Zabbix agent 2/mssql.uptime)<{$MSSQL.UPTIME.RESTART.WINDOW} and nodata(/SQLManiak MSSQL by Zabbix agent 2/mssql.uptime,5m)=0` | Unexpected SQL restart. |
| item: Uptime | MSSQL: Monitoring channel unavailable while TCP is reachable | `HIGH` | `nodata(/SQLManiak MSSQL by Zabbix agent 2/mssql.uptime,{$MSSQL.ODBC.NODATA})=1 and last(/SQLManiak MSSQL by Zabbix agent 2/net.tcp.service[tcp,{$MSSQL.HOST},{$MSSQL.PORT}])=1` | TCP reachable but Agent 2/MSSQL monitoring data stopped arriving. |
| item: Version | MSSQL: Version has changed | `INFO` | `last(...,#1)<>last(...,#2) and length(last(...))>0` | MSSQL version changed. |
| item: Work files created per second | MSSQL: Number of work files created per second is high | `AVERAGE` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.workfiles_created_sec.rate,5m)>{$MSSQL.WORK_FILES.MAX}` | High work-file creation rate. |
| item: Work tables created per second | MSSQL: Number of work tables created per second is high | `AVERAGE` | `min(/SQLManiak MSSQL by Zabbix agent 2/mssql.worktables_created_sec.rate,5m)>{$MSSQL.WORK_TABLES.MAX}` | High work-table creation rate. |
