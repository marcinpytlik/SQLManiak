# Inventory — triggery i trigger prototypes

Łącznie: **76**.

| Źródło | Trigger | Severity | Warunek | Opis |
|---|---|---|---|---|

> Część 2.

| item: Worktables from cache ratio | MSSQL: Percentage of work tables available from the work table cache is low | `HIGH` | `max(/SQLManiak MSSQL by Zabbix agent 2/mssql.worktables_from_cache_ratio,5m)<{$MSSQL.WORKTABLES_FROM_CACHE_RATIO.MIN.CRIT}` | Low worktable cache ratio. |
| item: Service's TCP port state | MSSQL: Service is unavailable | `DISASTER` | `last(/SQLManiak MSSQL by Zabbix agent 2/net.tcp.service[tcp,{$MSSQL.HOST},{$MSSQL.PORT}])=0` | TCP port unavailable. |
| item: Service's TCP port state | MSSQL: TCP port unavailable | `DISASTER` | `max(/SQLManiak MSSQL by Zabbix agent 2/net.tcp.service[tcp,{$MSSQL.HOST},{$MSSQL.PORT}],{$MSSQL.TCP.FAIL.COUNT})=0` | Root-cause availability alert after consecutive failed samples. |
| item: TCP connection time | MSSQL: TCP connection time is high | `HIGH` | `avg(/SQLManiak MSSQL by Zabbix agent 2/net.tcp.service.perf[tcp,{$MSSQL.HOST},{$MSSQL.PORT}],5m)>{$MSSQL.TCP.CRIT}` | TCP connect-time high. |
| item: TCP connection time | MSSQL: TCP connection time is elevated | `WARNING` | `avg(...,5m)>{$MSSQL.TCP.WARN} and avg(...,5m)<={$MSSQL.TCP.CRIT}` | TCP connect-time warning range. |
| item: SQLManiak E2E: connectivity status | MSSQL: E2E SQL path unavailable | `HIGH` | `max(/SQLManiak MSSQL by Zabbix agent 2/mssql.e2e.status,#3)=0` | Three consecutive E2E probes failed. |
| prototype: MSSQL AG '{#GROUP_NAME}': Primary replica recovery health | MSSQL: AG '{#GROUP_NAME}': Primary replica recovery health in progress | `WARNING` | `last(/SQLManiak MSSQL by Zabbix agent 2/mssql.primary_recovery_health["{#GROUP_NAME}"])=0` | Primary replica recovery in progress. |
| prototype: MSSQL AG '{#GROUP_NAME}': Secondary replica recovery health | MSSQL: AG '{#GROUP_NAME}': Secondary replica recovery health in progress | `WARNING` | `last(/SQLManiak MSSQL by Zabbix agent 2/mssql.secondary_recovery_health["{#GROUP_NAME}"])=0` | Secondary replica recovery in progress. |
| prototype: MSSQL AG '{#GROUP_NAME}': Synchronization health | MSSQL: AG '{#GROUP_NAME}': All replicas unhealthy | `DISASTER` | `last(/SQLManiak MSSQL by Zabbix agent 2/mssql.synchronization_health["{#GROUP_NAME}"])=0` | No healthy replicas. |
| prototype: MSSQL AG '{#GROUP_NAME}': Synchronization health | MSSQL: AG '{#GROUP_NAME}': Some replicas unhealthy | `HIGH` | `last(/SQLManiak MSSQL by Zabbix agent 2/mssql.synchronization_health["{#GROUP_NAME}"])=1` | Partial AG health. |
| discovery: Database discovery | MSSQL: DB '{#DBNAME}': LOG backup overdue - warning | `WARNING` | context macro enabled + DB ONLINE + non-SIMPLE + log age > WARN | LOG backup SLA warning. |
| discovery: Database discovery | MSSQL: DB '{#DBNAME}': LOG backup overdue - high | `HIGH` | context macro enabled + DB ONLINE + non-SIMPLE + log age > CRIT | LOG backup SLA violation. |
| prototype: MSSQL DB '{#DBNAME}': Last diff backup (time ago) | MSSQL: DB '{#DBNAME}': Diff backup is old | `HIGH` | `{$MSSQL.BACKUP_DIFF.USED:"{#DBNAME}"}=1` + age > CRIT | Differential backup overdue. |
| prototype: MSSQL DB '{#DBNAME}': Last diff backup (time ago) | MSSQL: DB '{#DBNAME}': Diff backup is old | `WARNING` | `{$MSSQL.BACKUP_DIFF.USED:"{#DBNAME}"}=1` + age > WARN | Differential backup warning. |
| prototype: MSSQL DB '{#DBNAME}': Last full backup (time ago) | MSSQL: DB '{#DBNAME}': Full backup is old | `HIGH` | `{$MSSQL.BACKUP_FULL.USED:"{#DBNAME}"}=1` + age > CRIT | Full backup overdue. |
| prototype: MSSQL DB '{#DBNAME}': Last full backup (time ago) | MSSQL: DB '{#DBNAME}': Full backup is old | `WARNING` | `{$MSSQL.BACKUP_FULL.USED:"{#DBNAME}"}=1` + age > WARN | Full backup warning. |
| prototype: MSSQL DB '{#DBNAME}': Log flush waits per second | MSSQL: DB '{#DBNAME}': Number of commits waiting for the log flush is high | `WARNING` | `min(...,5m)>{$MSSQL.LOG_FLUSH_WAITS.MAX:"{#DBNAME}"}` | Too many commits waiting for log flush. |
| prototype: MSSQL DB '{#DBNAME}': Log flush wait time | MSSQL: DB '{#DBNAME}': Total wait time to flush the log is high | `WARNING` | `min(...,5m)>{$MSSQL.LOG_FLUSH_WAIT_TIME.MAX:"{#DBNAME}"}` | Log flush wait time high. |
| prototype: MSSQL DB '{#DBNAME}': Percent log used | MSSQL: DB '{#DBNAME}': Percent of log usage is high | `WARNING` | `min(...,5m)>{$MSSQL.PERCENT_LOG_USED.MAX:"{#DBNAME}"}` | Log space usage above threshold. |
| prototype: MSSQL DB '{#DBNAME}': Percent log used | MSSQL: DB '{#DBNAME}': transaction log usage is high - warning | `WARNING` | `avg(...,10m)>{$MSSQL.LOG.USED.WARN:"{#DBNAME}"}` | Log-capacity warning. |
| prototype: MSSQL DB '{#DBNAME}': Percent log used | MSSQL: DB '{#DBNAME}': transaction log usage is critical | `HIGH` | `avg(...,5m)>{$MSSQL.LOG.USED.CRIT:"{#DBNAME}"}` | Critical log-capacity signal. |
| prototype: MSSQL DB '{#DBNAME}': State | MSSQL: DB '{#DBNAME}': State is {ITEM.VALUE} | `HIGH` | `last(...state...)>1` | DB non-working state. |
| prototype: MSSQL DB '{#DBNAME}': State | MSSQL: DB '{#DBNAME}': State is {ITEM.VALUE} [CRITICAL DB] | `DISASTER` | state != ONLINE and `{$MSSQL.DB.CRITICAL:"{#DBNAME}"}=1` | Critical DB not ONLINE. |
| prototype: MSSQL DB '{#DBNAME}': State | MSSQL: DB '{#DBNAME}': State is {ITEM.VALUE} [non-critical] | `HIGH` | state != ONLINE and `{$MSSQL.DB.CRITICAL:"{#DBNAME}"}=0` | Non-critical DB not ONLINE. |
| prototype: MSSQL Job '{#JOBNAME}': Last run date-time | MSSQL: Job '{#JOBNAME}': expected run is overdue | `WARNING` | `MAXAGE>0`, standard job, enabled, last-run age > MAXAGE | Missed-run alert. |
| prototype: MSSQL Job '{#JOBNAME}': Last run date-time | MSSQL: Job '{#JOBNAME}': critical expected run is overdue | `HIGH` | `MAXAGE>0`, critical job, enabled, last-run age > MAXAGE | Critical missed-run alert. |
| prototype: MSSQL Job '{#JOBNAME}': Run status | MSSQL: Job '{#JOBNAME}': Failed to run | `WARNING` | `runstatus=0` | Last run failed. |
| prototype: MSSQL Job '{#JOBNAME}': Run status | MSSQL: Job '{#JOBNAME}': last run failed/cancelled/retry | `WARNING` | runstatus in failed/retry/cancelled and standard job | Standard job failure result. |
| prototype: MSSQL Job '{#JOBNAME}': Run status | MSSQL: Job '{#JOBNAME}': critical job failed/cancelled/retry | `HIGH` | runstatus in failed/retry/cancelled and critical job | Critical job failure result. |
| prototype: MSSQL Job '{#JOBNAME}': Run duration | MSSQL: Job '{#JOBNAME}': Job duration is high | `WARNING` | `last(...run_duration...)>{$MSSQL.JOB_DURATION.WARN:"{#JOBNAME}"}` | Job duration above threshold. |
