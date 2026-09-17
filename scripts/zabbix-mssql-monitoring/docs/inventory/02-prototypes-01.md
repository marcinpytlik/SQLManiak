# Inwentarz — reguły wykrywania i prototypy itemów

Łącznie reguł wykrywania: **10**.

> Część 1 z 2 — Availability Groups, bazy danych, joby, local DB i mirroring.

Nazwy prototypów i klucze pozostają zgodne z rzeczywistym szablonem Zabbixa.

## Wykrywanie Availability Groups

- Klucz: `mssql.availability.group.discovery`
- Typ: `DEPENDENT`
- Liczba prototypów: **4**

| Prototyp | Klucz | Sposób zbierania | Co mierzy / znaczenie |
|---|---|---|---|
| MSSQL AG '{#GROUP_NAME}': Primary replica recovery health | `mssql.primary_recovery_health["{#GROUP_NAME}"]` | item zależny od `mssql.availability.group.get[...]` | Kondycja recovery repliki primary: `0` = w toku, `1` = online, `2` = niedostępna. |
| MSSQL AG '{#GROUP_NAME}': Primary replica name | `mssql.primary_replica["{#GROUP_NAME}"]` | item zależny od `mssql.availability.group.get[...]` | Nazwa instancji SQL Server hostującej aktualną replikę primary. |
| MSSQL AG '{#GROUP_NAME}': Secondary replica recovery health | `mssql.secondary_recovery_health["{#GROUP_NAME}"]` | item zależny od `mssql.availability.group.get[...]` | Kondycja recovery repliki secondary: `0` = w toku, `1` = online, `2` = niedostępna. |
| MSSQL AG '{#GROUP_NAME}': Synchronization health | `mssql.synchronization_health["{#GROUP_NAME}"]` | item zależny od `mssql.availability.group.get[...]` | Zbiorczy stan synchronizacji wszystkich replik należących do Availability Group. |

## Wykrywanie baz danych

- Klucz: `mssql.database.discovery`
- Typ: `DEPENDENT`
- Liczba prototypów: **38**

| Prototyp | Klucz | Sposób zbierania | Co mierzy / znaczenie |
|---|---|---|---|
| MSSQL DB '{#DBNAME}': Last diff backup duration | `mssql.backup.diff.duration["{#DBNAME}"]` | item zależny od `mssql.backup.raw["{#DBNAME}"]` | Czas trwania ostatniego backupu różnicowego. |
| MSSQL DB '{#DBNAME}': Last diff backup (time ago) | `mssql.backup.diff["{#DBNAME}"]` | item zależny od `mssql.backup.raw["{#DBNAME}"]` | Czas, jaki upłynął od ostatniego backupu różnicowego. |
| MSSQL DB '{#DBNAME}': Last full backup duration | `mssql.backup.full.duration["{#DBNAME}"]` | item zależny od `mssql.backup.raw["{#DBNAME}"]` | Czas trwania ostatniego pełnego backupu. |
| MSSQL DB '{#DBNAME}': Last full backup (time ago) | `mssql.backup.full["{#DBNAME}"]` | item zależny od `mssql.backup.raw["{#DBNAME}"]` | Czas, jaki upłynął od ostatniego pełnego backupu. |
| MSSQL DB '{#DBNAME}': Last log backup duration | `mssql.backup.log.duration["{#DBNAME}"]` | item zależny od `mssql.backup.raw["{#DBNAME}"]` | Czas trwania ostatniego backupu logu transakcyjnego. |
| MSSQL DB '{#DBNAME}': Last log backup (time ago) | `mssql.backup.log["{#DBNAME}"]` | item zależny od `mssql.backup.raw["{#DBNAME}"]` | Czas, jaki upłynął od ostatniego backupu logu transakcyjnego. |
| MSSQL DB '{#DBNAME}': Get last backup | `mssql.backup.raw["{#DBNAME}"]` | item zależny od `mssql.last.backup.get[...]` | Surowe informacje o ostatnich backupach bazy `{#DBNAME}` używane przez pozostałe itemy backupowe. |
| MSSQL DB '{#DBNAME}': Recovery model | `mssql.backup.recovery_model["{#DBNAME}"]` | item zależny od `mssql.backup.raw["{#DBNAME}"]` | Model odzyskiwania bazy: Full, Bulk_logged albo Simple. |
| MSSQL DB '{#DBNAME}': Active transactions | `mssql.db.active_transactions["{#DBNAME}"]` | item zależny od `mssql.db.perf_raw["{#DBNAME}"]` | Liczba aktywnych transakcji w danej bazie. |
| MSSQL DB '{#DBNAME}': Data file size | `mssql.db.data_files_size["{#DBNAME}"]` | item zależny od `mssql.db.perf_raw["{#DBNAME}"]` | Łączny rozmiar wszystkich plików danych bazy, z uwzględnieniem autogrowth. |
| MSSQL DB '{#DBNAME}': Log bytes flushed per second | `mssql.db.log_bytes_flushed_sec.rate["{#DBNAME}"]` | item zależny od `mssql.db.perf_raw["{#DBNAME}"]` | Liczba bajtów logu zapisywanych na dysk na sekundę. |
| MSSQL DB '{#DBNAME}': Log file size | `mssql.db.log_files_size["{#DBNAME}"]` | item zależny od `mssql.db.perf_raw["{#DBNAME}"]` | Łączny rozmiar plików logu transakcyjnego bazy. |
| MSSQL DB '{#DBNAME}': Log file used size | `mssql.db.log_files_used_size["{#DBNAME}"]` | item zależny od `mssql.db.perf_raw["{#DBNAME}"]` | Łączna zajęta przestrzeń plików logu transakcyjnego bazy. |
| MSSQL DB '{#DBNAME}': Log flushes per second | `mssql.db.log_flushes_sec.rate["{#DBNAME}"]` | item zależny od `mssql.db.perf_raw["{#DBNAME}"]` | Liczba operacji flush logu na sekundę. |
| MSSQL DB '{#DBNAME}': Log flush waits per second | `mssql.db.log_flush_waits_sec.rate["{#DBNAME}"]` | item zależny od `mssql.db.perf_raw["{#DBNAME}"]` | Liczba commitów na sekundę oczekujących na flush logu. |
| MSSQL DB '{#DBNAME}': Log flush wait time | `mssql.db.log_flush_wait_time["{#DBNAME}"]` | item zależny od `mssql.db.perf_raw["{#DBNAME}"]` | Łączny czas oczekiwania na flush logu. |
| MSSQL DB '{#DBNAME}': Log growths | `mssql.db.log_growths["{#DBNAME}"]` | item zależny od `mssql.db.perf_raw["{#DBNAME}"]` | Liczba operacji wzrostu pliku logu transakcyjnego. |
| MSSQL DB '{#DBNAME}': Log shrinks | `mssql.db.log_shrinks["{#DBNAME}"]` | item zależny od `mssql.db.perf_raw["{#DBNAME}"]` | Liczba operacji shrink pliku logu transakcyjnego. |
| MSSQL DB '{#DBNAME}': Log truncations | `mssql.db.log_truncations["{#DBNAME}"]` | item zależny od `mssql.db.perf_raw["{#DBNAME}"]` | Liczba operacji truncation logu. |
| MSSQL DB '{#DBNAME}': Percent log used | `mssql.db.percent_log_used["{#DBNAME}"]` | item zależny od `mssql.db.perf_raw["{#DBNAME}"]` | Procent zajętej przestrzeni logu transakcyjnego. |
| MSSQL DB '{#DBNAME}': Get performance counters | `mssql.db.perf_raw["{#DBNAME}"]` | item zależny od `mssql.perfcounter.get[...]` | Surowe liczniki wydajności dotyczące konkretnej bazy. |
| MSSQL DB '{#DBNAME}': State | `mssql.db.state["{#DBNAME}"]` | item zależny od `mssql.db.perf_raw["{#DBNAME}"]` | Stan bazy, np. Online, Restoring, Recovering, Recovery pending, Suspect, Emergency lub Offline. |
| MSSQL DB '{#DBNAME}': Transactions per second | `mssql.db.transactions_sec.rate["{#DBNAME}"]` | item zależny od `mssql.db.perf_raw["{#DBNAME}"]` | Liczba transakcji rozpoczynanych na sekundę w danej bazie. |
| MSSQL DB '{#DBNAME}': CPU time total | `mssql.db.cpu_time_ms_total["{#DBNAME}"]` | item zależny od `sqlmaniak_db_cpu` | Skumulowany czas CPU przypisany do bazy na podstawie plan cache. |
| MSSQL DB '{#DBNAME}': CPU time delta | `mssql.db.cpu_time_ms.delta["{#DBNAME}"]` | item zależny od `sqlmaniak_db_cpu` | Przyrost czasu CPU między kolejnymi próbkami. Ujemne wartości po resecie lub usunięciu planów są zabezpieczane. |
| MSSQL DB '{#DBNAME}': CPU ms per second | `mssql.db.cpu_ms_per_sec["{#DBNAME}"]` | item zależny od `sqlmaniak_db_cpu` | Liczba milisekund CPU zużywanych przez bazę na sekundę. |
| MSSQL DB '{#DBNAME}': CPU capacity utilization | `mssql.db.cpu_capacity_pct["{#DBNAME}"]` | item obliczany | Użycie CPU przez bazę względem maksymalnej pojemności schedulerów widocznych dla SQL Server. |
| MSSQL DB '{#DBNAME}': CPU workload share | `mssql.db.cpu_share_pct["{#DBNAME}"]` | item obliczany | Procent udziału bazy w przyroście CPU całego workloadu SQL Server. |
| MSSQL DB '{#DBNAME}': ROWS data files allocated size | `mssql.db.rows_data.allocated_mb["{#DBNAME}"]` | item zależny od `sqlmaniak_db_space` | Łączna zaalokowana przestrzeń plików danych typu ROWS. |
| MSSQL DB '{#DBNAME}': ROWS data files used size | `mssql.db.rows_data.used_mb["{#DBNAME}"]` | item zależny od `sqlmaniak_db_space` | Łączna wykorzystana przestrzeń w plikach ROWS. |
| MSSQL DB '{#DBNAME}': ROWS data files allocated free size | `mssql.db.rows_data.free_mb["{#DBNAME}"]` | item zależny od `sqlmaniak_db_space` | Zaalokowana, ale jeszcze niewykorzystana przestrzeń ROWS. |
| MSSQL DB '{#DBNAME}': ROWS data files used | `mssql.db.rows_data.used_pct["{#DBNAME}"]` | item zależny od `sqlmaniak_db_space` | Procent wykorzystania aktualnie zaalokowanej przestrzeni ROWS. |
| MSSQL DB '{#DBNAME}': ROWS allocated free space | `mssql.db.rows_data.allocated_free_pct["{#DBNAME}"]` | item zależny od `sqlmaniak_db_space` | Procent aktualnie zaalokowanej przestrzeni ROWS pozostający wolny. |
| MSSQL DB '{#DBNAME}': Estimated time until log reaches 100% | `mssql.db.log_timeleft["{#DBNAME}"]` | item obliczany `timeleft(...,1h,100)` | Prognozowany czas do osiągnięcia 100% wykorzystania logu na podstawie trendu `Percent Log Used`. |
| MSSQL DB '{#DBNAME}': TDE encrypted | `mssql.db.tde_encrypted["{#DBNAME}"]` | item zależny od `sqlmaniak_tde_status` | Wartość `1`, gdy `encryption_state=3`, w przeciwnym przypadku `0`. |
| MSSQL DB '{#DBNAME}': TDE encryption state | `mssql.db.tde_state["{#DBNAME}"]` | item zależny od `sqlmaniak_tde_status` | Surowy stan szyfrowania z `sys.dm_database_encryption_keys.encryption_state`; `0` oznacza brak wiersza DEK. |
| MSSQL DB '{#DBNAME}': VLF count | `mssql.db.vlf_count["{#DBNAME}"]` | item zależny od `sqlmaniak_vlf_count` | Liczba VLF w logu transakcyjnym bazy. |
| MSSQL DB '{#DBNAME}': ROWS estimated time until allocated space is full | `mssql.db.rows_data.timeleft["{#DBNAME}"]` | item obliczany `timeleft(...,6h,100)` | Prognozuje czas do wykorzystania całej aktualnie zaalokowanej przestrzeni ROWS. Nie jest to prognoza zapełnienia woluminu lub filesystemu. |

## Wykrywanie jobów SQL Server Agent

- Klucz: `mssql.job.discovery`
- Typ: `DEPENDENT`
- Liczba prototypów: **7**

| Prototyp | Klucz | Sposób zbierania | Co mierzy / znaczenie |
|---|---|---|---|
| MSSQL Job '{#JOBNAME}': Enabled | `mssql.job.enabled["{#JOBNAME}"]` | item zależny | Czy job jest włączony czy wyłączony. |
| MSSQL Job '{#JOBNAME}': Last run date-time | `mssql.job.lastrundatetime["{#JOBNAME}"]` | item zależny | Data i czas ostatniego uruchomienia joba. |
| MSSQL Job '{#JOBNAME}': Last run status message | `mssql.job.lastrunstatusmessage["{#JOBNAME}"]` | item zależny | Komunikat statusu z ostatniego uruchomienia. |
| MSSQL Job '{#JOBNAME}': Next run date-time | `mssql.job.nextrundatetime["{#JOBNAME}"]` | item zależny | Data i czas kolejnego zaplanowanego uruchomienia. |
| MSSQL Job '{#JOBNAME}': Run status | `mssql.job.runstatus["{#JOBNAME}"]` | item zależny | Status ostatniego lub bieżącego wykonania: Failed, Succeeded, Retry, Canceled lub Running. |
| MSSQL Job '{#JOBNAME}': Run duration | `mssql.job.run_duration["{#JOBNAME}"]` | item zależny | Czas trwania ostatniego uruchomienia joba. |
| MSSQL Job '{#JOBNAME}': Get job status | `mssql.job.status_raw["{#JOBNAME}"]` | item zależny od `mssql.job.status.get[...]` | Surowe dane statusu joba używane przez pozostałe prototypy. |

## Wykrywanie lokalnych baz Availability Group

- Klucz: `mssql.local.db.discovery`
- Typ: `DEPENDENT`
- Liczba prototypów: **3**

| Prototyp | Klucz | Sposób zbierania | Co mierzy / znaczenie |
|---|---|---|---|
| MSSQL AG '{#GROUP_NAME}' Local DB '{#DBNAME}': Suspended | `mssql.local_db.is_suspended["{#DBNAME}"]` | item zależny | Czy synchronizacja lokalnej bazy AG jest wznowiona czy zawieszona. |
| MSSQL AG '{#GROUP_NAME}' Local DB '{#DBNAME}': State | `mssql.local_db.state["{#DBNAME}"]` | item zależny | Stan lokalnej bazy należącej do Availability Group. |
| MSSQL AG '{#GROUP_NAME}' Local DB '{#DBNAME}': Synchronization health | `mssql.local_db.synchronization_health["{#DBNAME}"]` | item zależny | Kondycja synchronizacji lokalnej bazy Availability Group. |

## Wykrywanie Database Mirroring

- Klucz: `mssql.mirroring.discovery`
- Typ: `DEPENDENT`
- Liczba prototypów: **5**

| Prototyp | Klucz | Sposób zbierania | Co mierzy / znaczenie |
|---|---|---|---|
| MSSQL Mirroring '{#DBNAME}': Role | `mssql.mirroring.role["{#DBNAME}"]` | item zależny | Rola bazy w mirroringu: Principal albo Mirror. |
| MSSQL Mirroring '{#DBNAME}': Role sequence | `mssql.mirroring.role_sequence["{#DBNAME}"]` | item zależny | Licznik zmian roli w konfiguracji mirroringu. |
| MSSQL Mirroring '{#DBNAME}': Safety level | `mssql.mirroring.safety_level["{#DBNAME}"]` | item zależny | Poziom bezpieczeństwa mirroringu, odpowiadający pracy asynchronicznej lub synchronicznej. |
| MSSQL Mirroring '{#DBNAME}': State | `mssql.mirroring.state["{#DBNAME}"]` | item zależny | Aktualny stan Database Mirroring. |
| MSSQL Mirroring '{#DBNAME}': Witness state | `mssql.mirroring.witness_state["{#DBNAME}"]` | item zależny | Stan witnessa w konfiguracji mirroringu. |
