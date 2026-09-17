# Inventory — items instancji

Łącznie: **139**. Opis pochodzi z aktualnego YAML; „Jak” wskazuje faktyczny mechanizm zbierania.

| Nazwa | Key | Jak | Co mierzy / sens |
|---|---|---|---|

> Część 2.

| Total log file size | `mssql.log_files_size` | dependent z `mssql.db_info.raw` | Total size of all the transaction log files. |
| Total log file used size | `mssql.log_files_used_size` | dependent z `mssql.db_info.raw` | The cumulative size of all the log files in the database. |
| Maximum workspace memory | `mssql.maximum_workspace_memory` | dependent z `mssql.mem_manager.raw` | Indicates the maximum amount of memory available for executing processes, such as hash, sort, bulk copy, and index creation operations. |
| Memory grants outstanding | `mssql.memory_grants_outstanding` | dependent z `mssql.mem_manager.raw` | Specifies the total number of processes that have successfully acquired a workspace memory grant. |
| Memory grants pending | `mssql.memory_grants_pending` | dependent z `mssql.mem_manager.raw` | Specifies the total number of processes waiting for a workspace memory grant. |
| Get Memory counters | `mssql.mem_manager.raw` | dependent z `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | The item gets memory information. |
| Get DB mirroring | `mssql.mirroring.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → MSSQL plugin | Getting DB mirroring. |
| Get non-local DB | `mssql.nonlocal.db.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → MSSQL plugin | Getting the non-local availability database. |
| Total lock requests per second that have deadlocks | `mssql.number_deadlocks_sec.rate` | dependent z `mssql.locks_info.raw` | Number of lock requests per second that resulted in a deadlock. |
| Errors per second (DB offline errors) | `mssql.offline_errors_sec.rate` | dependent z `mssql.sql_errors.raw` | Number of errors per second. |
| Page life expectancy | `mssql.page_life_expectancy` | dependent z `mssql.buffer_manager.raw` | Indicates the number of seconds a page will stay in the buffer pool without references. |
| Page lookups per second | `mssql.page_lookups_sec.rate` | dependent z `mssql.buffer_manager.raw` | Indicates the number of requests per second to find a page in the buffer pool. |
| Page reads per second | `mssql.page_reads_sec.rate` | dependent z `mssql.buffer_manager.raw` | Indicates the number of physical database page reads that are issued per second. This statistic displays the total number of physical page reads across all databases. As physical I/O is expensive, you may be able to minimize the cost either by using a larger d… |
| Page splits per second | `mssql.page_splits_sec.rate` | dependent z `mssql.access_methods.raw` | Number of page splits per second that occur as a result of overflowing index pages. |
| Page writes per second | `mssql.page_writes_sec.rate` | dependent z `mssql.buffer_manager.raw` | Indicates the number of physical database page writes that are issued per second. |
| Percent of ad hoc queries running | `mssql.percent_of_adhoc_queries` | calculated: `last(//mssql.sql_compilations_sec.rate) * 100 / (last(//mssql.batch_requests_sec.rate) + (last(//mssql.batch_requests_se…` | The ratio of SQL compilations per second to batch requests per second, in percent. |
| Percent of Recompiled Transact-SQL Objects | `mssql.percent_recompilations_to_compilations` | calculated: `last(//mssql.sql_recompilations_sec.rate) * 100 / (last(//mssql.sql_compilations_sec.rate) + (last(//mssql.sql_compilati…` | The ratio of SQL re-compilations per second to SQL compilations per second, in percent. |
| Get performance counters | `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → MSSQL plugin | The item gets server global status information. |
| Number of blocked processes | `mssql.processes_blocked` | dependent z `mssql.general_statistics.raw` | Number of currently blocked processes. |
| Get quorum | `mssql.quorum.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → MSSQL plugin | Getting quorum - cluster name, type, and state. |
| Get quorum member | `mssql.quorum.member.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → MSSQL plugin | Getting quorum members - member name, type, state, and number of quorum votes. |
| Read-ahead pages per second | `mssql.readahead_pages_sec.rate` | dependent z `mssql.buffer_manager.raw` | Indicates the number of pages read per second in anticipation of use. |
| Get replica | `mssql.replica.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → MSSQL plugin | Getting the database replica. |
| Safe auto-params per second | `mssql.safe_autoparams_sec.rate` | dependent z `mssql.sql_statistics.raw` | Number of safe auto-parameterization attempts per second. Safe refers to a determination that a cached execution plan can be shared between different similar-looking Transact-SQL statements. SQL Server makes many auto-parameterization attempts, some of which t… |
| Full scans to Index searches ratio | `mssql.scan_to_search` | calculated: `last(//mssql.full_scans_sec.rate) / (last(//mssql.index_searches_sec.rate) + (last(//mssql.index_searches_sec.rate)=0))` | The ratio of full scans per second to index searches per second. The threshold recommendation is strictly for OLTP workloads. |
| SQL compilations per second | `mssql.sql_compilations_sec.rate` | dependent z `mssql.sql_statistics.raw` | Number of SQL compilations per second. Indicates the number of times the compile code path is entered. Includes runs caused by statement-level recompilations in SQL Server. After SQL Server user activity is stable, this value reaches a steady state. |
| Get SQL Errors counters | `mssql.sql_errors.raw` | dependent z `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | The item gets SQL error information. |
| SQL re-compilations per second | `mssql.sql_recompilations_sec.rate` | dependent z `mssql.sql_statistics.raw` | Number of statement recompiles per second. Counts the number of times statement recompiles are triggered. Generally, you want the recompiles to be low. |
| Get SQL Statistics counters | `mssql.sql_statistics.raw` | dependent z `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | The item gets SQL statistics information. |
| Table lock escalations per second | `mssql.table_lock_escalations.rate` | dependent z `mssql.access_methods.raw` | Number of times locks on a table were escalated to the TABLE or HoBT granularity. |
| Target pages | `mssql.target_pages` | dependent z `mssql.buffer_manager.raw` | The optimal number of pages in the buffer pool. |
| Target server memory | `mssql.target_server_memory` | dependent z `mssql.mem_manager.raw` | Indicates the ideal amount of memory the server can consume. |
| Total latch wait time | `mssql.total_latch_wait_time` | dependent z `mssql.latches_info.raw` | Total latch wait time (in milliseconds) for latch requests in the last second. This value should stay stable compared to the number of latch waits per second. |
| Total server memory | `mssql.total_server_memory` | dependent z `mssql.mem_manager.raw` | Specifies the amount of memory the server has committed using the memory manager. |
| Total transactions number | `mssql.transactions` | dependent z `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | The number of currently active transactions of all types. |
| Total transactions per second | `mssql.transactions_sec.rate` | dependent z `mssql.db_info.raw` | Total number of transactions started for all databases per second. |
| Unsafe auto-params per second | `mssql.unsafe_autoparams_sec.rate` | dependent z `mssql.sql_statistics.raw` | Number of unsafe auto-parameterization attempts per second. For example, the query has some characteristics that prevent the cached plan from being shared. These are designated as unsafe. This does not count the number of forced parameterizations. |
| Uptime | `mssql.uptime` | dependent z `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | MSSQL Server uptime in the format "N days, hh:mm:ss". |
| Number of users connected | `mssql.user_connections` | dependent z `mssql.general_statistics.raw` | Number of users connected to MSSQL Server. |
| Errors per second (User errors) | `mssql.user_errors_sec.rate` | dependent z `mssql.sql_errors.raw` | Number of errors per second. |
| Version | `mssql.version["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → MSSQL plugin | MSSQL Server version. |
| Work files created per second | `mssql.workfiles_created_sec.rate` | dependent z `mssql.access_methods.raw` | Number of work files created per second. For example, work files can be used to store temporary results for hash joins and hash aggregates. |
| Work tables created per second | `mssql.worktables_created_sec.rate` | dependent z `mssql.access_methods.raw` | Number of work tables created per second. For example, work tables can be used to store temporary results for query spool, LOB variables, XML variables, and cursors. |
| Worktables from cache ratio | `mssql.worktables_from_cache_ratio` | dependent z `mssql.access_methods.raw` | Percentage of work tables created where the initial two pages of the work table were not allocated but were immediately available from the work table cache. |
| Service's TCP port state | `net.tcp.service[tcp,{$MSSQL.HOST},{$MSSQL.PORT}]` | Zabbix simple TCP check | Test the availability of MSSQL Server on a TCP port. |
