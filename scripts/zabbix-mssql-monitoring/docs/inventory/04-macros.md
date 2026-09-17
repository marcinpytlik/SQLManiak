# Inventory — makra

Łącznie: **64**.

| Makro | Default | Opis |
|---|---|---|
| `{$MSSQL.AGENT2.NODATA}` | `5m` |  |
| `{$MSSQL.AVERAGE_WAIT_TIME.MAX}` | `500` | The maximum average wait time, in milliseconds - for the trigger expression. |
| `{$MSSQL.AVGWAIT.CRIT}` | `1000` | Blocking HIGH average wait time threshold in ms. |
| `{$MSSQL.BACKUP_DIFF.CRIT}` | `8h` | DIFF backup HIGH age. |
| `{$MSSQL.BACKUP_DIFF.USED}` | `1` | Enable DIFF backup SLA; override per DB to 0 to disable. |
| `{$MSSQL.BACKUP_DIFF.WARN}` | `6h` | DIFF backup WARNING age. |
| `{$MSSQL.BACKUP_FULL.CRIT}` | `36h` | FULL backup HIGH age. |
| `{$MSSQL.BACKUP_FULL.USED}` | `1` | Enable FULL backup SLA; override per DB to 0 to disable. |
| `{$MSSQL.BACKUP_FULL.WARN}` | `30h` | FULL backup WARNING age. |
| `{$MSSQL.BACKUP_LOG.CRIT}` | `1h` | LOG backup HIGH age. |
| `{$MSSQL.BACKUP_LOG.USED}` | `1` | Enable LOG backup SLA; SIMPLE recovery is excluded by trigger. |
| `{$MSSQL.BACKUP_LOG.WARN}` | `30m` | LOG backup WARNING age. |
| `{$MSSQL.BUFFER_CACHE_RATIO.MIN.CRIT}` | `30` | The minimum buffer cache hit ratio, in percent - for the High trigger expression. |
| `{$MSSQL.BUFFER_CACHE_RATIO.MIN.WARN}` | `50` | The minimum buffer cache hit ratio, in percent - for the Warning trigger expression. |
| `{$MSSQL.DB.CRITICAL}` | `0` | Default DB criticality; override per database context to 1. |
| `{$MSSQL.DBNAME.MATCHES}` | `.*` | This macro is used in database discovery. It can be overridden on the host or linked template level. |
| `{$MSSQL.DBNAME.NOT_MATCHES}` | `master/tempdb/model/msdb` | This macro is used in database discovery. It can be overridden on the host or linked template level. |
| `{$MSSQL.DEADLOCK.CRIT.COUNT}` | `5` | Deadlock burst HIGH threshold over 10 minutes. |
| `{$MSSQL.DEADLOCKS.MAX}` | `1` | The maximum deadlocks per second - for the trigger expression. |
| `{$MSSQL.E2E.AGENT.PORT}` | `10050` | Zabbix Agent 2 passive port used by the server-side E2E external check. |
| `{$MSSQL.E2E.BASELINE.SEASONS}` | `7` | Documentation macro: seasonal E2E baseline uses 7 previous daily seasons in v1.6. |
| `{$MSSQL.E2E.BASELINE.WARMUP}` | `7d` | Documentation macro: allow at least 7 days before interpreting seasonal baseline/deviation. |
| `{$MSSQL.E2E.INTERVAL}` | `1m` | Polling interval documentation macro for the E2E check. The item delay is 1m in v1.5. |
| `{$MSSQL.FREELIST.CRIT.TIME}` | `15m` | Free List Stalls HIGH persistence. |
| `{$MSSQL.FREELIST.WARN.TIME}` | `5m` | Free List Stalls WARNING persistence. |
| `{$MSSQL.FREE_LIST_STALLS.MAX}` | `2` | The maximum free list stalls per second - for the trigger expression. |
| `{$MSSQL.HOST}` | `localhost` | The hostname or IP address of the MSSQL instance. |
| `{$MSSQL.JOB.CRITICAL}` | `0` | Default SQL Agent job criticality; override per job context to 1. |
| `{$MSSQL.JOB.MATCHES}` | `.*` | This macro is used in job discovery. It can be overridden on the host or linked template level. |
| `{$MSSQL.JOB.MAXAGE}` | `0` | Expected maximum age of last job run in seconds; 0 disables missed-run alert. |
| `{$MSSQL.JOB.NOT_MATCHES}` | `CHANGE_IF_NEEDED` | This macro is used in job discovery. It can be overridden on the host or linked template level. |
| `{$MSSQL.JOB_DURATION.WARN}` | `1h` | The maximum job duration - for the Warning trigger expression. |
| `{$MSSQL.LAZY_WRITES.MAX}` | `20` | The maximum lazy writes per second - for the trigger expression. |
| `{$MSSQL.LOCKWAITS.WARN}` | `0` | Initial lock-waits correlation threshold; tune per instance after baseline. |
| `{$MSSQL.LOCK_REQUESTS.MAX}` | `1000` | The maximum lock requests per second - for the trigger expression. |
| `{$MSSQL.LOCK_TIMEOUTS.MAX}` | `1` | The maximum lock timeouts per second - for the trigger expression. |
| `{$MSSQL.LOG.USED.CRIT}` | `90` | Transaction log used percent HIGH. |
| `{$MSSQL.LOG.USED.WARN}` | `80` | Transaction log used percent WARNING. |
| `{$MSSQL.LOG_FLUSH_WAITS.MAX}` | `1` | The maximum log flush waits per second - for the trigger expression. |
| `{$MSSQL.LOG_FLUSH_WAIT_TIME.MAX}` | `1` | The maximum log flush wait time, in milliseconds - for the trigger expression. |
| `{$MSSQL.MEMGRANT.CRIT.TIME}` | `15m` | Memory Grants Pending HIGH persistence. |
| `{$MSSQL.MEMGRANT.WARN.TIME}` | `5m` | Memory Grants Pending WARNING persistence. |
| `{$MSSQL.ODBC.NODATA}` | `5m` | No MSSQL uptime data while TCP is reachable. |
| `{$MSSQL.PAGE_LIFE_EXPECTANCY.MIN}` | `300` | The minimum page life (in seconds) expectancy - for the trigger expression. |
| `{$MSSQL.PAGE_READS.MAX}` | `90` | The maximum page reads per second - for the trigger expression. |
| `{$MSSQL.PAGE_WRITES.MAX}` | `90` | The maximum page writes per second - for the trigger expression. |
| `{$MSSQL.PASSWORD}` | `` | MSSQL database password. |
| `{$MSSQL.PERCENT_COMPILATIONS.MAX}` | `10` | The maximum percentage of Transact-SQL compilations - for the trigger expression. |
| `{$MSSQL.PERCENT_LOG_USED.MAX}` | `80` | The maximum percentage of log used - for the trigger expression. |
| `{$MSSQL.PERCENT_READAHEAD.MAX}` | `20` | The maximum percentage of pages read per second in anticipation of use - for the trigger expression. |
| `{$MSSQL.PERCENT_RECOMPILATIONS.MAX}` | `10` | The maximum percentage of Transact-SQL recompilations - for the trigger expression. |
| `{$MSSQL.PORT}` | `1433` | MSSQL TCP port. |
| `{$MSSQL.QUORUM.MEMBER.DISCOVERY.NAME.MATCHES}` | `.*` | Filter to include discovered quorum member by name. |
| `{$MSSQL.QUORUM.MEMBER.DISCOVERY.NAME.NOT_MATCHES}` | `CHANGE_IF_NEEDED` | Filter to exclude discovered quorum member by name. |
| `{$MSSQL.TCP.CRIT}` | `1` | TCP connect time HIGH in seconds (1000 ms). |
| `{$MSSQL.TCP.FAIL.COUNT}` | `#3` | P1 TCP failure: three failed samples. |
| `{$MSSQL.TCP.RECOVERY.COUNT}` | `#2` | P1 TCP recovery: two successful samples. |
| `{$MSSQL.TCP.WARN}` | `0.25` | TCP connect time WARNING in seconds (250 ms). |
| `{$MSSQL.UPTIME.RESTART.WINDOW}` | `600` | Unexpected restart window in seconds. |
| `{$MSSQL.URI}` | `` | Connection string. |
| `{$MSSQL.USER}` | `` | MSSQL database username. |
| `{$MSSQL.WORKTABLES_FROM_CACHE_RATIO.MIN.CRIT}` | `90` | The minimum percentage of work tables from the cache ratio - for the High trigger expression. |
| `{$MSSQL.WORK_FILES.MAX}` | `20` | The maximum number of work files created per second - for the trigger expression. |
| `{$MSSQL.WORK_TABLES.MAX}` | `20` | The maximum number of work tables created per second - for the trigger expression. |
