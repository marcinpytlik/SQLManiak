# Excel → Zabbix: arkusz „Macierz alertów”, pozycje 50–82

**Źródło:** `MSSQL_alerty_Grafana_macierz_v6_complete_CPU_SQL(2).xlsx`  
**Szablon docelowy:** `SQLManiak_MSSQL_Zabbix_7.4_matrix_v1.6_baseline_anomaly`

| Lp. | Sekcja | Metryka z Excela | Klucz z Excela | Klasa | Status | Implementacja w szablonie | Uwagi |
|---:|---|---|---|---|---|---|---|
| 50 | Baza danych | Czas do zapełnienia przestrzeni plików danych | `mssql.data_files_timeleft` | ALERT | 🟡 Częściowo / inaczej | `mssql.db.rows_data.timeleft["{#DBNAME}"]` | Prognoza dotyczy zapełnienia aktualnie zaalokowanej przestrzeni ROWS per baza, a nie całego filesystemu. |
| 51 | Baza danych | Maksymalna liczba VLF na instancji | `mssql.vlf_count.max` | ALERT | ✅ Zaimplementowane | `mssql.vlf_count.max` — VLF count - maximum across user databases | Klucz zgodny z arkuszem. |
| 52 | Bezpieczeństwo | Liczba baz bez TDE | `mssql.tde.not_encrypted_count` | ALERT | ✅ Zaimplementowane | `mssql.tde.not_encrypted_count` — TDE: user databases not encrypted | Klucz zgodny z arkuszem. |
| 53 | Baza danych | DB '{#DBNAME}': stan | `mssql.db.state["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.db.state["{#DBNAME}"]` | Klucz zgodny z arkuszem. |
| 54 | Baza danych | DB '{#DBNAME}': wykorzystanie zaalokowanej przestrzeni ROWS (%) | `mssql.db.rows_data.used_pct["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.db.rows_data.used_pct["{#DBNAME}"]` | Klucz zgodny z arkuszem. |
| 55 | Baza danych | DB '{#DBNAME}': wolna zaalokowana przestrzeń ROWS (%) | `mssql.db.rows_data.allocated_free_pct["{#DBNAME}"]` | DASHBOARD | ✅ Zaimplementowane | `mssql.db.rows_data.allocated_free_pct["{#DBNAME}"]` | Klucz zgodny z arkuszem. |
| 56 | Baza danych | DB '{#DBNAME}': wykorzystanie logu (%) | `mssql.db.percent_log_used["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.db.percent_log_used["{#DBNAME}"]` | Klucz zgodny z arkuszem. |
| 57 | Baza danych | DB '{#DBNAME}': prognozowany czas do pełnego logu | `mssql.db.log_timeleft["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.db.log_timeleft["{#DBNAME}"]` | Klucz zgodny z arkuszem. |
| 58 | Baza danych | DB '{#DBNAME}': oczekiwania na flush logu/s | `mssql.db.log_flush_waits_sec.rate["{#DBNAME}"]` | TREND | ✅ Zaimplementowane | `mssql.db.log_flush_waits_sec.rate["{#DBNAME}"]` | Klucz zgodny z arkuszem. |
| 59 | Baza danych | DB '{#DBNAME}': transakcje/s | `mssql.db.transactions_sec.rate["{#DBNAME}"]` | TREND | ✅ Zaimplementowane | `mssql.db.transactions_sec.rate["{#DBNAME}"]` | Klucz zgodny z arkuszem. |
| 60 | Baza danych | DB '{#DBNAME}': aktywne transakcje | `mssql.db.active_transactions["{#DBNAME}"]` | TREND | ✅ Zaimplementowane | `mssql.db.active_transactions["{#DBNAME}"]` | Klucz zgodny z arkuszem. |
| 61 | Backup | DB '{#DBNAME}': czas od ostatniego backupu FULL | `mssql.backup.full["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.backup.full["{#DBNAME}"]` | Klucz zgodny z arkuszem. |
| 62 | Backup | DB '{#DBNAME}': czas od ostatniego backupu LOG | `mssql.backup.log["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.backup.log["{#DBNAME}"]` | Klucz zgodny z arkuszem. |
| 63 | Backup | DB '{#DBNAME}': czas od ostatniego backupu DIFF | `mssql.backup.diff["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.backup.diff["{#DBNAME}"]` | Klucz zgodny z arkuszem. |
| 64 | Backup | DB '{#DBNAME}': recovery model | `mssql.backup.recovery_model["{#DBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.backup.recovery_model["{#DBNAME}"]` | Klucz zgodny z arkuszem. |
| 65 | Baza danych | DB '{#DBNAME}' FG '{#FILEGROUP}': wykorzystanie (%) | `mssql.db.filegroup.used_pct["{#DBNAME}","{#FILEGROUP}"]` | ALERT | ✅ Zaimplementowane | `mssql.db.filegroup.used_pct[...]` | Klucz zgodny z arkuszem. |
| 66 | Baza danych | DB '{#DBNAME}' FG '{#FILEGROUP}': wolna zaalokowana przestrzeń (MB) | `mssql.db.filegroup.free_mb["{#DBNAME}","{#FILEGROUP}"]` | ALERT | ✅ Zaimplementowane | `mssql.db.filegroup.free_mb[...]` | Klucz zgodny z arkuszem. To wolna przestrzeń wewnątrz zaalokowanych plików, nie wolne miejsce na dysku. |
| 67 | Baza danych | DB '{#DBNAME}' FG '{#FILEGROUP}': zaalokowany rozmiar (MB) | `mssql.db.filegroup.allocated_mb["{#DBNAME}","{#FILEGROUP}"]` | DASHBOARD | ✅ Zaimplementowane | `mssql.db.filegroup.allocated_mb[...]` | Klucz zgodny z arkuszem. |
| 68 | SQL Server Agent | Job '{#JOBNAME}': status wykonania | `mssql.job.runstatus["{#JOBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.job.runstatus["{#JOBNAME}"]` | Klucz zgodny z arkuszem. |
| 69 | SQL Server Agent | Job '{#JOBNAME}': czas trwania | `mssql.job.run_duration["{#JOBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.job.run_duration["{#JOBNAME}"]` | Klucz zgodny z arkuszem. |
| 70 | SQL Server Agent | Job '{#JOBNAME}': data i czas ostatniego uruchomienia | `mssql.job.lastrundatetime["{#JOBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.job.lastrundatetime["{#JOBNAME}"]` | Klucz zgodny z arkuszem. |
| 71 | SQL Server Agent | Job '{#JOBNAME}': włączony / wyłączony | `mssql.job.enabled["{#JOBNAME}"]` | ALERT | ✅ Zaimplementowane | `mssql.job.enabled["{#JOBNAME}"]` | Klucz zgodny z arkuszem. |
| 72 | Warstwa techniczna ODBC | Główny master liczników wydajności | `db.odbc.get[get_status_variables,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione przez Agent 2 | `mssql.perfcounter.get[...]` + itemy zależne `raw` | Arkusz zakładał ODBC. Aktualny szablon używa dodatku MSSQL dla Zabbix Agent 2. |
| 73 | Warstwa techniczna ODBC | Pobranie informacji o ostatnim backupie | `db.odbc.get[get_last_backup,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione przez Agent 2 | `mssql.last.backup.get[...]` | Informacje o backupach pobiera natywny dodatek MSSQL. |
| 74 | Warstwa techniczna ODBC | Pobranie danych o filegroupach | `db.odbc.get[filegroups,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione własnym zapytaniem | `mssql.custom.query[...,sqlmaniak_filegroups]` | Filegroupy są zbierane przez własne zapytanie wykonywane przez Agent 2. |
| 75 | Warstwa techniczna ODBC | Pobranie listy baz | `db.odbc.get[get_database,{$MSSQL.DSN}]` | TECHNICAL | 🔁 Zastąpione przez Agent 2 | `mssql.db.get[...]` | Discovery baz korzysta z natywnego dodatku MSSQL. |
| 76 | Warstwa techniczna ODBC | Pobranie statusu jobów | `db.odbc.get[get_job_status,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione przez Agent 2 | `mssql.job.status.get[...]` | Status SQL Server Agent jest pobierany przez natywny dodatek MSSQL. |
| 77 | Warstwa techniczna ODBC | Surowe dane o wykorzystaniu CPU | `db.odbc.get[cpu_utilization,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione własnym zapytaniem | `mssql.custom.query[...,sqlmaniak_cpu_health]` | Własny kolektor CPU i schedulerów SQLManiak. |
| 78 | Warstwa techniczna ODBC | Surowe dane o opóźnieniu I/O | `db.odbc.get[io_stall,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione własnym zapytaniem | `mssql.custom.query[...,sqlmaniak_io_latency]` | Własny kolektor opóźnienia I/O SQLManiak. |
| 79 | Warstwa techniczna ODBC | Długotrwałe transakcje | `db.odbc.get[long_transactions,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione własnym zapytaniem | `mssql.custom.query[...,sqlmaniak_long_transactions]` | Kolektor aktywnych i długotrwałych transakcji. |
| 80 | Warstwa techniczna ODBC | Wykorzystanie przestrzeni ROWS | `db.odbc.get[rows_data_space,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione własnym zapytaniem | `mssql.custom.query[...,sqlmaniak_db_space]` | Kolektor przestrzeni ROWS per baza danych. |
| 81 | Warstwa techniczna ODBC | Stan szyfrowania TDE | `db.odbc.get[tde_status,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione własnym zapytaniem | `mssql.custom.query[...,sqlmaniak_tde_status]` | Stan TDE jest zbierany per baza danych. |
| 82 | Warstwa techniczna ODBC | Liczba VLF | `db.odbc.get[vlf_count,"{$MSSQL.DSN}"]` | TECHNICAL | 🔁 Zastąpione własnym zapytaniem | `mssql.custom.query[...,sqlmaniak_vlf_count]` | Kolektor zwraca VLF per baza oraz maksimum dla całej instancji. |
