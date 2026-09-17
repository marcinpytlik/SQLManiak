# Excel → Zabbix: arkusz „Macierz alertów”, pozycje 50–82

| Lp. | Sekcja | Excel: metryka | Excel key | Klasa | Status | Implementacja w szablonie | Uwagi |
|---:|---|---|---|---|---|---|---|
| 50 | Database | Data files — czas do wzrostu (s) | `mssql.data_files_timeleft` | ALERT | 🟡 Częściowo / inaczej | `mssql.db.rows_data.timeleft["{#DBNAME}"]` | Prognoza dotyczy zapełnienia aktualnie zaalokowanej przestrzeni ROWS per DB, nie całego filesystemu. |
| 51 | Database | VLF count — max (instancja) | `mssql.vlf_count.max` | ALERT | ✅ Zaimplementowane | `mssql.vlf_count.max` — VLF count - maximum across user databases | Key zgodny z Excelem. |
| 52 | Security | TDE — bazy bez szyfrowania | `mssql.tde.not_encrypted_count` | ALERT | ✅ Zaimplementowane | `mssql.tde.not_encrypted_count` — TDE: user databases not encrypted | Key zgodny z Excelem. |
| 53 | Database | DB '{#DBNAME}': Stan | `mssql.db.state["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.db.state["{#DBNAME}"]` | Key zgodny z Excelem. |
| 54 | Database | DB '{#DBNAME}': ROWS data files used (%) | `mssql.db.rows_data.used_pct["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.db.rows_data.used_pct["{#DBNAME}"]` | Key zgodny z Excelem. |
| 55 | Database | DB '{#DBNAME}': ROWS allocated free space (%) | `mssql.db.rows_data.allocated_free_pct["{#DBNAME}"]` | DASHBOARD | ✅ Zaimplementowane | `mssql.db.rows_data.allocated_free_pct["{#DBNAME}"]` | Key zgodny z Excelem. |
| 56 | Database | DB '{#DBNAME}': Percent log used (%) | `mssql.db.percent_log_used["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.db.percent_log_used["{#DBNAME}"]` | Key zgodny z Excelem. |
| 57 | Database | DB '{#DBNAME}': Estimated time until log full (s) | `mssql.db.log_timeleft["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.db.log_timeleft["{#DBNAME}"]` | Key zgodny z Excelem. |
| 58 | Database | DB '{#DBNAME}': Log flush waits/sec | `mssql.db.log_flush_waits_sec.rate["{#DBNAME}"]` | TREND | ✅ Zaimplementowane | `mssql.db.log_flush_waits_sec.rate["{#DBNAME}"]` | Key zgodny z Excelem. |
| 59 | Database | DB '{#DBNAME}': Transactions/sec | `mssql.db.transactions_sec.rate["{#DBNAME}"]` | TREND | ✅ Zaimplementowane | `mssql.db.transactions_sec.rate["{#DBNAME}"]` | Key zgodny z Excelem. |
| 60 | Database | DB '{#DBNAME}': Active transactions | `mssql.db.active_transactions["{#DBNAME}"]` | TREND | ✅ Zaimplementowane | `mssql.db.active_transactions["{#DBNAME}"]` | Key zgodny z Excelem. |
| 61 | Backup | DB '{#DBNAME}': Last full backup (time ago) | `mssql.backup.full["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.backup.full["{#DBNAME}"]` | Key zgodny z Excelem. |
| 62 | Backup | DB '{#DBNAME}': Last log backup (time ago) | `mssql.backup.log["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.backup.log["{#DBNAME}"]` | Key zgodny z Excelem. |
| 63 | Backup | DB '{#DBNAME}': Last diff backup (time ago) | `mssql.backup.diff["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.backup.diff["{#DBNAME}"]` | Key zgodny z Excelem. |
| 64 | Backup | DB '{#DBNAME}': Recovery model | `mssql.backup.recovery_model["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.backup.recovery_model["{#DBNAME}"]` | Key zgodny z Excelem. |
| 65 | Database | DB '{#DBNAME}' FG '{#FILEGROUP}': used (%) | `mssql.db.filegroup.used_pct["{#DBNAME}","{#FILEGROUP}"]` | ALERT | ✅ Zaimplementowane | `mssql.db.filegroup.used_pct[...]` | Key zgodny z Excelem. |
| 66 | Database | DB '{#DBNAME}' FG '{#FILEGROUP}': free size (MB) | `mssql.db.filegroup.free_mb["{#DBNAME}","{#FILEGROUP}"]` | ALERT | ✅ Zaimplementowane | `mssql.db.filegroup.free_mb[...]` | Key zgodny z Excelem. |
| 67 | Database | DB '{#DBNAME}' FG '{#FILEGROUP}': allocated size (MB) | `mssql.db.filegroup.allocated_mb["{#DBNAME}","{#FILEGROUP}"]` | DASHBOARD | ✅ Zaimplementowane | `mssql.db.filegroup.allocated_mb[...]` | Key zgodny z Excelem. |
| 68 | Agent | MSSQL Job '{#JOBNAME}': Run status | `mssql.job.runstatus["{#JOBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.job.runstatus["{#JOBNAME}"]` | Key zgodny z Excelem. |
| 69 | Agent | MSSQL Job '{#JOBNAME}': Run duration (s) | `mssql.job.run_duration["{#JOBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.job.run_duration["{#JOBNAME}"]` | Key zgodny z Excelem. |
| 70 | Agent | MSSQL Job '{#JOBNAME}': Last run date-time | `mssql.job.lastrundatetime["{#JOBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.job.lastrundatetime["{#JOBNAME}"]` | Key zgodny z Excelem. |
| 71 | Agent | MSSQL Job '{#JOBNAME}': Enabled | `mssql.job.enabled["{#JOBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.job.enabled["{#JOBNAME}"]` | Key zgodny z Excelem. |
| 72 | Master ODBC | Get performance counters (główny master) | `db.odbc.get[get_status_variables,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione Agent 2 | `mssql.perfcounter.get[...]` + dependent raw items | Excel zakładał ODBC; aktualny szablon używa MSSQL Agent 2 plugin. |
| 73 | Master ODBC | Get last backup | `db.odbc.get[get_last_backup,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione Agent 2 | `mssql.last.backup.get[...]` | Master backup przez MSSQL plugin. |
| 74 | Master ODBC | Get filegroups data | `db.odbc.get[filegroups,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione custom query | `mssql.custom.query[...,sqlmaniak_filegroups]` | Filegroupy zbierane custom query Agent 2. |
| 75 | Master ODBC | Get database | `db.odbc.get[get_database,{$MSSQL.DSN}]` | TECHNICAL | 🔁 Zastąpione Agent 2 | `mssql.db.get[...]` | Discovery baz przez MSSQL plugin. |
| 76 | Master ODBC | Get job status | `db.odbc.get[get_job_status,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione Agent 2 | `mssql.job.status.get[...]` | Status SQL Agent przez MSSQL plugin. |
| 77 | Master ODBC | CPU utilization raw | `db.odbc.get[cpu_utilization,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione custom query | `mssql.custom.query[...,sqlmaniak_cpu_health]` | CPU/scheduler collector. |
| 78 | Master ODBC | I/O stall raw | `db.odbc.get[io_stall,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione custom query | `mssql.custom.query[...,sqlmaniak_io_latency]` | I/O latency collector. |
| 79 | Master ODBC | Long-running transactions | `db.odbc.get[long_transactions,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione custom query | `mssql.custom.query[...,sqlmaniak_long_transactions]` | Long/active transactions collector. |
| 80 | Master ODBC | ROWS data files space usage | `db.odbc.get[rows_data_space,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione custom query | `mssql.custom.query[...,sqlmaniak_db_space]` | ROWS space per database. |
| 81 | Master ODBC | TDE encryption status | `db.odbc.get[tde_status,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione custom query | `mssql.custom.query[...,sqlmaniak_tde_status]` | TDE per DB. |
| 82 | Master ODBC | VLF count | `db.odbc.get[vlf_count,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione custom query | `mssql.custom.query[...,sqlmaniak_vlf_count]` | VLF per DB + max across instance. |
