# Inventory — items instancji

Łącznie: **139**. Opis pochodzi z aktualnego YAML; „Jak” wskazuje faktyczny mechanizm zbierania.

> Część 1 z 4.

| Nazwa | Key | Jak | Co mierzy / sens |
|---|---|---|---|
| Get Access Methods counters | `mssql.access_methods.raw` | dependent z `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | The item gets server information about access methods. |
| Auto-param attempts per second | `mssql.autoparam_attempts_sec.rate` | dependent z `mssql.sql_statistics.raw` | Number of auto-parameterization attempts per second. The total should be the sum of the failed, safe, and unsafe auto-parameterizations. Auto-parameterization occurs when an instance of SQL Server tries to parameterize a Transact-SQL request by replacing some … |
| Get availability groups | `mssql.availability.group.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → MSSQL plugin | The item gets availability group states - name, primary and secondary health, synchronization health. |
| Average latch wait time | `mssql.average_latch_wait_time` | calculated: `(last(//mssql.average_latch_wait_time_raw) - last(//mssql.average_latch_wait_time_raw,#2)) / (last(//mssql.average_latch…` | Average latch wait time (in milliseconds) for latch requests that had to wait. |
| Average latch wait time base | `mssql.average_latch_wait_time_base` | dependent z `mssql.latches_info.raw` | For internal use only. |
| Average latch wait time raw | `mssql.average_latch_wait_time_raw` | dependent z `mssql.latches_info.raw` | Average latch wait time (in milliseconds) for latch requests that had to wait. |
| Total average wait time | `mssql.average_wait_time` | calculated: `(last(//mssql.average_wait_time_raw) - last(//mssql.average_wait_time_raw,#2)) / (last(//mssql.average_wait_time_base) -…` | The average wait time, in milliseconds, for each lock request that had to wait. |
| Total average wait time base | `mssql.average_wait_time_base` | dependent z `mssql.locks_info.raw` | For internal use only. |
| Total average wait time raw | `mssql.average_wait_time_raw` | dependent z `mssql.locks_info.raw` | Average amount of wait time (in milliseconds) for each lock request that resulted in a wait. Information for all locks. |
| Batch requests per second | `mssql.batch_requests_sec.rate` | dependent z `mssql.sql_statistics.raw` | Number of Transact-SQL command batches received per second. This statistic is affected by all constraints (such as I/O, number of users, cache size, complexity of requests, and so on). High batch requests mean good throughput. |
| Buffer cache hit ratio | `mssql.buffer_cache_hit_ratio` | dependent z `mssql.buffer_manager.raw` | Indicates the percentage of pages found in the buffer cache without having to read from the disk. The ratio is the total number of cache hits divided by the total number of cache lookups over the last few thousand page accesses. After a long period of time, th… |
| Get Buffer Manager counters | `mssql.buffer_manager.raw` | dependent z `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | The item gets server information about the buffer pool. |
| Cache hit ratio | `mssql.cache_hit_ratio` | dependent z `mssql.cache_info.raw` | Ratio between cache hits and lookups. |
| Get Cache counters | `mssql.cache_info.raw` | dependent z `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | The item gets server information about cache. |
| Cache objects in use | `mssql.cache_objects_in_use` | dependent z `mssql.cache_info.raw` | Number of cache objects in use. |
| Cache object counts | `mssql.cache_object_counts` | dependent z `mssql.cache_info.raw` | Number of cache objects in the cache. |
| Cache pages | `mssql.cache_pages` | dependent z `mssql.cache_info.raw` | Number of 8-kilobyte (KB) pages used by cache objects. |
| Checkpoint pages per second | `mssql.checkpoint_pages_sec.rate` | dependent z `mssql.buffer_manager.raw` | Indicates the number of pages flushed to the disk per second by a checkpoint or other operation which required all dirty pages to be flushed. |
| Database pages | `mssql.database_pages` | dependent z `mssql.buffer_manager.raw` | Indicates the number of pages in the buffer pool with database content. |
| Total data file size | `mssql.data_files_size` | dependent z `mssql.db_info.raw` | Total size of all data files. |
| Get database | `mssql.db.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → MSSQL plugin | Getting databases - database name and recovery model. |
| Get DB counters | `mssql.db_info.raw` | dependent z `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | The item gets summary information about databases. |
| Total errors per second | `mssql.errors_sec.rate` | dependent z `mssql.sql_errors.raw` | Number of errors per second. |
| Failed auto-params per second | `mssql.failed_autoparams_sec.rate` | dependent z `mssql.sql_statistics.raw` | Number of failed auto-parameterization attempts per second. This number should be small. Note that auto-parameterizations are also known as simple parameterizations in the newer versions of SQL Server. |
| Forwarded records per second | `mssql.forwarded_records_sec.rate` | dependent z `mssql.access_methods.raw` | Number of records per second fetched through forwarded record pointers. |
| Free list stalls per second | `mssql.free_list_stalls_sec.rate` | dependent z `mssql.buffer_manager.raw` | Indicates the number of requests per second that had to wait for a free page. |
| Full scans per second | `mssql.full_scans_sec.rate` | dependent z `mssql.access_methods.raw` | Number of unrestricted full scans per second. These can be either base-table or full-index scans. Values greater than 1 or 2 indicate that there are table / index page scans. If that is combined with high CPU, this counter requires further investigation, other… |
| Get General Statistics counters | `mssql.general_statistics.raw` | dependent z `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | The item gets general statistics information. |
| Granted Workspace Memory | `mssql.granted_workspace_memory` | dependent z `mssql.mem_manager.raw` | Specifies the total amount of memory currently granted to executing processes, such as hash, sort, bulk copy, and index creation operations. |
| Index searches per second | `mssql.index_searches_sec.rate` | dependent z `mssql.access_methods.raw` | Number of index searches per second. These are used to start a range scan, reposition a range scan, revalidate a scan point, fetch a single index record, and search down the index to locate where to insert a new row. |
| Errors per second (Info errors) | `mssql.info_errors_sec.rate` | dependent z `mssql.sql_errors.raw` | Number of errors per second. |
| Get job status | `mssql.job.status.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → MSSQL plugin | The item gets the SQL agent job status. |
| Errors per second (Kill connection errors) | `mssql.kill_connection_errors_sec.rate` | dependent z `mssql.sql_errors.raw` | Number of errors per second. |
| Get last backup | `mssql.last.backup.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → MSSQL plugin | The item gets information about backup processes. |
| Get Latches counters | `mssql.latches_info.raw` | dependent z `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | The item gets server information about latches. |
| Latch waits per second | `mssql.latch_waits_sec.rate` | dependent z `mssql.latches_info.raw` | The number of latch requests that could not be granted immediately. Latches are lightweight means of holding a very transient server resource, such as an address in memory. |
| Lazy writes per second | `mssql.lazy_writes_sec.rate` | dependent z `mssql.buffer_manager.raw` | Indicates the number of buffers written per second by the buffer manager's lazy writer. The lazy writer is a system process that flushes out batches of dirty, aged buffers (buffers that contain changes that must be written back to the disk before the buffer ca… |
| Get local DB | `mssql.local.db.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → MSSQL plugin | Getting the states of the local availability database. |
| Get Locks counters | `mssql.locks_info.raw` | dependent z `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | The item gets server information about locks. |
| Total lock requests per second | `mssql.lock_requests_sec.rate` | dependent z `mssql.locks_info.raw` | Number of new locks and lock conversions per second requested from the lock manager. |
| Total lock requests per second that timed out | `mssql.lock_timeouts_sec.rate` | dependent z `mssql.locks_info.raw` | Number of timed out lock requests per second, including requests for NOWAIT locks. |
| Total lock requests per second that required waiting | `mssql.lock_waits_sec.rate` | dependent z `mssql.locks_info.raw` | Number of lock requests per second that required the caller to wait. |
| Lock wait time | `mssql.lock_wait_time` | dependent z `mssql.locks_info.raw` | Average of total wait time (in milliseconds) for locks in the last second. |
| Logins per second | `mssql.logins_sec.rate` | dependent z `mssql.general_statistics.raw` | Total number of logins started per second. This does not include pooled connections. Any value over 2 may indicate insufficient connection pooling. |
| Logouts per second | `mssql.logouts_sec.rate` | dependent z `mssql.general_statistics.raw` | Total number of logout operations started per second. Any value over 2 may indicate insufficient connection pooling. |
