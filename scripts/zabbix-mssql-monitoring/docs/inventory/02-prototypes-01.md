# Inventory — discovery i item prototypes

Łącznie discovery rules: **10**.

> Część 1 z 2.

## Availability group discovery

- Key: `mssql.availability.group.discovery`
- Typ: `DEPENDENT`
- Prototypes: **4**

| Prototype | Key | Jak | Co mierzy / sens |
|---|---|---|---|
| MSSQL AG '{#GROUP_NAME}': Primary replica recovery health | `mssql.primary_recovery_health["{#GROUP_NAME}"]` | dependent z `mssql.availability.group.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Indicates the recovery health of the primary replica: 0 = In progress 1 = Online 2 = Unavailable |
| MSSQL AG '{#GROUP_NAME}': Primary replica name | `mssql.primary_replica["{#GROUP_NAME}"]` | dependent z `mssql.availability.group.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Name of the server instance that is hosting the current primary replica. |
| MSSQL AG '{#GROUP_NAME}': Secondary replica recovery health | `mssql.secondary_recovery_health["{#GROUP_NAME}"]` | dependent z `mssql.availability.group.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Indicates the recovery health of a secondary replica: 0 = In progress 1 = Online 2 = Unavailable |
| MSSQL AG '{#GROUP_NAME}': Synchronization health | `mssql.synchronization_health["{#GROUP_NAME}"]` | dependent z `mssql.availability.group.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Reflects a rollup of the synchronization health of all availability replicas in the availability group. |

## Database discovery

- Key: `mssql.database.discovery`
- Typ: `DEPENDENT`
- Prototypes: **38**

| Prototype | Key | Jak | Co mierzy / sens |
|---|---|---|---|
| MSSQL DB '{#DBNAME}': Last diff backup duration | `mssql.backup.diff.duration["{#DBNAME}"]` | dependent z `mssql.backup.raw["{#DBNAME}"]` | Duration of the last differential backup. |
| MSSQL DB '{#DBNAME}': Last diff backup (time ago) | `mssql.backup.diff["{#DBNAME}"]` | dependent z `mssql.backup.raw["{#DBNAME}"]` | The amount of time since the last differential backup. |
| MSSQL DB '{#DBNAME}': Last full backup duration | `mssql.backup.full.duration["{#DBNAME}"]` | dependent z `mssql.backup.raw["{#DBNAME}"]` | Duration of the last full backup. |
| MSSQL DB '{#DBNAME}': Last full backup (time ago) | `mssql.backup.full["{#DBNAME}"]` | dependent z `mssql.backup.raw["{#DBNAME}"]` | The amount of time since the last full backup. |
| MSSQL DB '{#DBNAME}': Last log backup duration | `mssql.backup.log.duration["{#DBNAME}"]` | dependent z `mssql.backup.raw["{#DBNAME}"]` | Duration of the last log backup. |
| MSSQL DB '{#DBNAME}': Last log backup (time ago) | `mssql.backup.log["{#DBNAME}"]` | dependent z `mssql.backup.raw["{#DBNAME}"]` | The amount of time since the last log backup. |
| MSSQL DB '{#DBNAME}': Get last backup | `mssql.backup.raw["{#DBNAME}"]` | dependent z `mssql.last.backup.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | The item gets information about backup processes for {#DBNAME}. |
| MSSQL DB '{#DBNAME}': Recovery model | `mssql.backup.recovery_model["{#DBNAME}"]` | dependent z `mssql.backup.raw["{#DBNAME}"]` | Recovery model selected: Full / Bulk_logged / Simple. |
| MSSQL DB '{#DBNAME}': Active transactions | `mssql.db.active_transactions["{#DBNAME}"]` | dependent z `mssql.db.perf_raw["{#DBNAME}"]` | Number of active transactions for the database. |
| MSSQL DB '{#DBNAME}': Data file size | `mssql.db.data_files_size["{#DBNAME}"]` | dependent z `mssql.db.perf_raw["{#DBNAME}"]` | Cumulative size of all data files in the database including automatic growth. |
| MSSQL DB '{#DBNAME}': Log bytes flushed per second | `mssql.db.log_bytes_flushed_sec.rate["{#DBNAME}"]` | dependent z `mssql.db.perf_raw["{#DBNAME}"]` | Log bytes flushed per second. |
| MSSQL DB '{#DBNAME}': Log file size | `mssql.db.log_files_size["{#DBNAME}"]` | dependent z `mssql.db.perf_raw["{#DBNAME}"]` | Cumulative transaction log file size. |
| MSSQL DB '{#DBNAME}': Log file used size | `mssql.db.log_files_used_size["{#DBNAME}"]` | dependent z `mssql.db.perf_raw["{#DBNAME}"]` | Cumulative used log file size. |
| MSSQL DB '{#DBNAME}': Log flushes per second | `mssql.db.log_flushes_sec.rate["{#DBNAME}"]` | dependent z `mssql.db.perf_raw["{#DBNAME}"]` | Number of log flushes per second. |
| MSSQL DB '{#DBNAME}': Log flush waits per second | `mssql.db.log_flush_waits_sec.rate["{#DBNAME}"]` | dependent z `mssql.db.perf_raw["{#DBNAME}"]` | Commits per second waiting for log flush. |
| MSSQL DB '{#DBNAME}': Log flush wait time | `mssql.db.log_flush_wait_time["{#DBNAME}"]` | dependent z `mssql.db.perf_raw["{#DBNAME}"]` | Total wait time to flush the log. |
| MSSQL DB '{#DBNAME}': Log growths | `mssql.db.log_growths["{#DBNAME}"]` | dependent z `mssql.db.perf_raw["{#DBNAME}"]` | Number of transaction-log growths. |
| MSSQL DB '{#DBNAME}': Log shrinks | `mssql.db.log_shrinks["{#DBNAME}"]` | dependent z `mssql.db.perf_raw["{#DBNAME}"]` | Number of transaction-log shrinks. |
| MSSQL DB '{#DBNAME}': Log truncations | `mssql.db.log_truncations["{#DBNAME}"]` | dependent z `mssql.db.perf_raw["{#DBNAME}"]` | Number of log truncations. |
| MSSQL DB '{#DBNAME}': Percent log used | `mssql.db.percent_log_used["{#DBNAME}"]` | dependent z `mssql.db.perf_raw["{#DBNAME}"]` | Percentage of log space in use. |
| MSSQL DB '{#DBNAME}': Get performance counters | `mssql.db.perf_raw["{#DBNAME}"]` | dependent z `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Server status counters for the database. |
| MSSQL DB '{#DBNAME}': State | `mssql.db.state["{#DBNAME}"]` | dependent z `mssql.db.perf_raw["{#DBNAME}"]` | Database state (Online, Restoring, Recovering, Recovery pending, Suspect, Emergency, Offline, etc.). |
| MSSQL DB '{#DBNAME}': Transactions per second | `mssql.db.transactions_sec.rate["{#DBNAME}"]` | dependent z `mssql.db.perf_raw["{#DBNAME}"]` | Transactions started for the database per second. |
| MSSQL DB '{#DBNAME}': CPU time total | `mssql.db.cpu_time_ms_total["{#DBNAME}"]` | dependent z `mssql.custom.query["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}",sqlmaniak_db_cpu]` | Cumulative plan-cache CPU total for the database. |
| MSSQL DB '{#DBNAME}': CPU time delta | `mssql.db.cpu_time_ms.delta["{#DBNAME}"]` | dependent z `mssql.custom.query["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}",sqlmaniak_db_cpu]` | CPU time delta between samples; reset/eviction negative values are clamped. |
| MSSQL DB '{#DBNAME}': CPU ms per second | `mssql.db.cpu_ms_per_sec["{#DBNAME}"]` | dependent z `mssql.custom.query["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}",sqlmaniak_db_cpu]` | Database CPU milliseconds consumed per second. |
| MSSQL DB '{#DBNAME}': CPU capacity utilization | `mssql.db.cpu_capacity_pct["{#DBNAME}"]` | calculated | Database CPU usage relative to SQL Server visible scheduler capacity. |
| MSSQL DB '{#DBNAME}': CPU workload share | `mssql.db.cpu_share_pct["{#DBNAME}"]` | calculated | Share of SQL workload CPU delta attributed to the database. |
| MSSQL DB '{#DBNAME}': ROWS data files allocated size | `mssql.db.rows_data.allocated_mb["{#DBNAME}"]` | dependent z `sqlmaniak_db_space` | ROWS internal allocated space. |
| MSSQL DB '{#DBNAME}': ROWS data files used size | `mssql.db.rows_data.used_mb["{#DBNAME}"]` | dependent z `sqlmaniak_db_space` | ROWS internal used space. |
| MSSQL DB '{#DBNAME}': ROWS data files allocated free size | `mssql.db.rows_data.free_mb["{#DBNAME}"]` | dependent z `sqlmaniak_db_space` | Allocated-but-unused ROWS space. |
| MSSQL DB '{#DBNAME}': ROWS data files used | `mssql.db.rows_data.used_pct["{#DBNAME}"]` | dependent z `sqlmaniak_db_space` | Percent of allocated ROWS space used. |
| MSSQL DB '{#DBNAME}': ROWS allocated free space | `mssql.db.rows_data.allocated_free_pct["{#DBNAME}"]` | dependent z `sqlmaniak_db_space` | Percent of allocated ROWS space still free. |
| MSSQL DB '{#DBNAME}': Estimated time until log reaches 100% | `mssql.db.log_timeleft["{#DBNAME}"]` | calculated `timeleft(...,1h,100)` | Predictive time-to-full from Percent Log Used. |
| MSSQL DB '{#DBNAME}': TDE encrypted | `mssql.db.tde_encrypted["{#DBNAME}"]` | dependent z `sqlmaniak_tde_status` | 1 when encryption_state=3, otherwise 0. |
| MSSQL DB '{#DBNAME}': TDE encryption state | `mssql.db.tde_state["{#DBNAME}"]` | dependent z `sqlmaniak_tde_status` | Raw `sys.dm_database_encryption_keys.encryption_state`; 0 means no DEK row. |
| MSSQL DB '{#DBNAME}': VLF count | `mssql.db.vlf_count["{#DBNAME}"]` | dependent z `sqlmaniak_vlf_count` | Number of VLFs in transaction log. |
| MSSQL DB '{#DBNAME}': ROWS estimated time until allocated space is full | `mssql.db.rows_data.timeleft["{#DBNAME}"]` | calculated `timeleft(...,6h,100)` | Predicts exhaustion of current allocated ROWS space, not filesystem exhaustion. |

## Job discovery

- Key: `mssql.job.discovery`
- Typ: `DEPENDENT`
- Prototypes: **7**

| Prototype | Key | Jak | Co mierzy / sens |
|---|---|---|---|
| MSSQL Job '{#JOBNAME}': Enabled | `mssql.job.enabled["{#JOBNAME}"]` | dependent | Enabled/disabled. |
| MSSQL Job '{#JOBNAME}': Last run date-time | `mssql.job.lastrundatetime["{#JOBNAME}"]` | dependent | Last run timestamp. |
| MSSQL Job '{#JOBNAME}': Last run status message | `mssql.job.lastrunstatusmessage["{#JOBNAME}"]` | dependent | Last run status message. |
| MSSQL Job '{#JOBNAME}': Next run date-time | `mssql.job.nextrundatetime["{#JOBNAME}"]` | dependent | Next scheduled run. |
| MSSQL Job '{#JOBNAME}': Run status | `mssql.job.runstatus["{#JOBNAME}"]` | dependent | Failed / Succeeded / Retry / Canceled / Running. |
| MSSQL Job '{#JOBNAME}': Run duration | `mssql.job.run_duration["{#JOBNAME}"]` | dependent | Last-run duration. |
| MSSQL Job '{#JOBNAME}': Get job status | `mssql.job.status_raw["{#JOBNAME}"]` | dependent z `mssql.job.status.get[...]` | Raw job status. |

## Local database discovery

- Key: `mssql.local.db.discovery`
- Typ: `DEPENDENT`
- Prototypes: **3**

| Prototype | Key | Jak | Co mierzy / sens |
|---|---|---|---|
| MSSQL AG '{#GROUP_NAME}' Local DB '{#DBNAME}': Suspended | `mssql.local_db.is_suspended["{#DBNAME}"]` | dependent | Resumed/Suspended. |
| MSSQL AG '{#GROUP_NAME}' Local DB '{#DBNAME}': State | `mssql.local_db.state["{#DBNAME}"]` | dependent | Local AG database state. |
| MSSQL AG '{#GROUP_NAME}' Local DB '{#DBNAME}': Synchronization health | `mssql.local_db.synchronization_health["{#DBNAME}"]` | dependent | Local AG database synchronization health. |

## Mirroring discovery

- Key: `mssql.mirroring.discovery`
- Typ: `DEPENDENT`
- Prototypes: **5**

| Prototype | Key | Jak | Co mierzy / sens |
|---|---|---|---|
| MSSQL Mirroring '{#DBNAME}': Role | `mssql.mirroring.role["{#DBNAME}"]` | dependent | Principal/Mirror role. |
| MSSQL Mirroring '{#DBNAME}': Role sequence | `mssql.mirroring.role_sequence["{#DBNAME}"]` | dependent | Count of role switches. |
| MSSQL Mirroring '{#DBNAME}': Safety level | `mssql.mirroring.safety_level["{#DBNAME}"]` | dependent | Async/sync safety. |
| MSSQL Mirroring '{#DBNAME}': State | `mssql.mirroring.state["{#DBNAME}"]` | dependent | Mirroring state. |
| MSSQL Mirroring '{#DBNAME}': Witness state | `mssql.mirroring.witness_state["{#DBNAME}"]` | dependent | Witness state. |
