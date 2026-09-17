# Inwentarz — makra

Łącznie w szablonie: **64 makra**.

Wartości w kolumnie „Domyślnie” pochodzą z aktualnego szablonu. Makra kontekstowe można nadpisywać per host, per baza danych lub per job — zależnie od sposobu użycia w triggerach i discovery.

| Makro | Domyślnie | Opis |
|---|---:|---|
| `{$MSSQL.AGENT2.NODATA}` | `5m` | Czas bez nowych danych z Agent 2, po którym można traktować kanał monitoringu jako niedostępny. |
| `{$MSSQL.AVERAGE_WAIT_TIME.MAX}` | `500` | Maksymalny dopuszczalny średni czas oczekiwania na blokadę w ms dla triggera. |
| `{$MSSQL.AVGWAIT.CRIT}` | `1000` | Krytyczny próg średniego czasu oczekiwania na blokadę w ms używany w korelacji z blockingiem. |
| `{$MSSQL.BACKUP_DIFF.CRIT}` | `8h` | Krytyczny maksymalny wiek backupu różnicowego. |
| `{$MSSQL.BACKUP_DIFF.USED}` | `1` | Włącza kontrolę SLA backupu DIFF. Ustaw `0` w kontekście konkretnej bazy, aby wyłączyć kontrolę. |
| `{$MSSQL.BACKUP_DIFF.WARN}` | `6h` | Ostrzegawczy maksymalny wiek backupu różnicowego. |
| `{$MSSQL.BACKUP_FULL.CRIT}` | `36h` | Krytyczny maksymalny wiek backupu pełnego. |
| `{$MSSQL.BACKUP_FULL.USED}` | `1` | Włącza kontrolę SLA backupu FULL. Ustaw `0` w kontekście konkretnej bazy, aby wyłączyć kontrolę. |
| `{$MSSQL.BACKUP_FULL.WARN}` | `30h` | Ostrzegawczy maksymalny wiek backupu pełnego. |
| `{$MSSQL.BACKUP_LOG.CRIT}` | `1h` | Krytyczny maksymalny wiek backupu logu transakcyjnego. |
| `{$MSSQL.BACKUP_LOG.USED}` | `1` | Włącza kontrolę SLA backupu LOG. Bazy w modelu SIMPLE są wykluczane przez warunek triggera. |
| `{$MSSQL.BACKUP_LOG.WARN}` | `30m` | Ostrzegawczy maksymalny wiek backupu logu transakcyjnego. |
| `{$MSSQL.BUFFER_CACHE_RATIO.MIN.CRIT}` | `30` | Krytyczny minimalny współczynnik trafień w buffer cache, w procentach. |
| `{$MSSQL.BUFFER_CACHE_RATIO.MIN.WARN}` | `50` | Ostrzegawczy minimalny współczynnik trafień w buffer cache, w procentach. |
| `{$MSSQL.DB.CRITICAL}` | `0` | Domyślna krytyczność bazy. Ustaw `1` jako makro kontekstowe dla baz wymagających poziomu DISASTER przy stanie innym niż ONLINE. |
| `{$MSSQL.DBNAME.MATCHES}` | `.*` | Filtr nazw baz uwzględnianych przez discovery. Może być nadpisany na hoście lub w powiązanym szablonie. |
| `{$MSSQL.DBNAME.NOT_MATCHES}` | `master/tempdb/model/msdb` | Filtr nazw baz wykluczanych przez discovery. Domyślnie wyklucza bazy systemowe. |
| `{$MSSQL.DEADLOCK.CRIT.COUNT}` | `5` | Liczba deadlocków w oknie 10 minut powodująca alert wysokiego poziomu o serii deadlocków. |
| `{$MSSQL.DEADLOCKS.MAX}` | `1` | Maksymalna liczba deadlocków na sekundę dla klasycznego triggera progowego. |
| `{$MSSQL.E2E.AGENT.PORT}` | `10050` | Port pasywnego Zabbix Agent 2 używany przez zewnętrzny test E2E po stronie Zabbix Server/Proxy. |
| `{$MSSQL.E2E.BASELINE.SEASONS}` | `7` | Makro dokumentacyjne: sezonowa linia bazowa E2E wykorzystuje siedem poprzednich dni. |
| `{$MSSQL.E2E.BASELINE.WARMUP}` | `7d` | Makro dokumentacyjne: minimalny zalecany okres zbierania danych przed interpretacją sezonowej linii bazowej i odchylenia. |
| `{$MSSQL.E2E.INTERVAL}` | `1m` | Makro dokumentacyjne interwału odpytywania E2E. Item w aktualnej wersji jest wykonywany co minutę. |
| `{$MSSQL.FREELIST.CRIT.TIME}` | `15m` | Czas utrzymywania się `Free List Stalls`, po którym generowany jest alert wysokiego poziomu. |
| `{$MSSQL.FREELIST.WARN.TIME}` | `5m` | Czas utrzymywania się `Free List Stalls`, po którym generowane jest ostrzeżenie. |
| `{$MSSQL.FREE_LIST_STALLS.MAX}` | `2` | Maksymalna liczba `Free List Stalls` na sekundę dla triggera progowego. |
| `{$MSSQL.HOST}` | `localhost` | Nazwa hosta lub adres IP monitorowanej instancji MSSQL używany m.in. w testach TCP. |
| `{$MSSQL.JOB.CRITICAL}` | `0` | Domyślna krytyczność joba SQL Server Agent. Ustaw `1` jako makro kontekstowe dla jobów krytycznych. |
| `{$MSSQL.JOB.MATCHES}` | `.*` | Filtr nazw jobów uwzględnianych przez discovery. |
| `{$MSSQL.JOB.MAXAGE}` | `0` | Maksymalny oczekiwany wiek ostatniego uruchomienia joba, w sekundach. `0` wyłącza alert o pominiętym uruchomieniu. |
| `{$MSSQL.JOB.NOT_MATCHES}` | `CHANGE_IF_NEEDED` | Filtr nazw jobów wykluczanych przez discovery. |
| `{$MSSQL.JOB_DURATION.WARN}` | `1h` | Maksymalny czas trwania joba przed wygenerowaniem ostrzeżenia. |
| `{$MSSQL.LAZY_WRITES.MAX}` | `20` | Maksymalna liczba lazy writes na sekundę dla triggera. |
| `{$MSSQL.LOCKWAITS.WARN}` | `0` | Początkowy próg korelacji dla lock waits. Wartość należy dostroić per instancja po zebraniu linii bazowej. |
| `{$MSSQL.LOCK_REQUESTS.MAX}` | `1000` | Maksymalna liczba żądań blokad na sekundę dla triggera. |
| `{$MSSQL.LOCK_TIMEOUTS.MAX}` | `1` | Maksymalna liczba timeoutów blokad na sekundę dla triggera. |
| `{$MSSQL.LOG.USED.CRIT}` | `90` | Krytyczny próg procentowego wykorzystania logu transakcyjnego. |
| `{$MSSQL.LOG.USED.WARN}` | `80` | Ostrzegawczy próg procentowego wykorzystania logu transakcyjnego. |
| `{$MSSQL.LOG_FLUSH_WAITS.MAX}` | `1` | Maksymalna liczba oczekiwań na flush logu na sekundę dla triggera. |
| `{$MSSQL.LOG_FLUSH_WAIT_TIME.MAX}` | `1` | Maksymalny czas oczekiwania na flush logu w milisekundach dla triggera. |
| `{$MSSQL.MEMGRANT.CRIT.TIME}` | `15m` | Czas utrzymywania się `Memory Grants Pending` powodujący alert wysokiego poziomu. |
| `{$MSSQL.MEMGRANT.WARN.TIME}` | `5m` | Czas utrzymywania się `Memory Grants Pending` powodujący ostrzeżenie. |
| `{$MSSQL.ODBC.NODATA}` | `5m` | Czas bez danych `mssql.uptime` przy jednocześnie dostępnym porcie TCP. Nazwa makra pozostała historyczna po rozwiązaniu opartym o ODBC. |
| `{$MSSQL.PAGE_LIFE_EXPECTANCY.MIN}` | `300` | Minimalny dopuszczalny Page Life Expectancy w sekundach dla triggera. |
| `{$MSSQL.PAGE_READS.MAX}` | `90` | Maksymalna liczba fizycznych odczytów stron na sekundę dla triggera. |
| `{$MSSQL.PAGE_WRITES.MAX}` | `90` | Maksymalna liczba fizycznych zapisów stron na sekundę dla triggera. |
| `{$MSSQL.PASSWORD}` | `` | Hasło konta MSSQL. Może pozostać puste, jeśli używana jest nazwana sesja dodatku MSSQL Agent 2. |
| `{$MSSQL.PERCENT_COMPILATIONS.MAX}` | `10` | Maksymalny procent kompilacji Transact-SQL względem batch requests dla triggera. |
| `{$MSSQL.PERCENT_LOG_USED.MAX}` | `80` | Maksymalny procent wykorzystania logu dla starszego triggera progowego. |
| `{$MSSQL.PERCENT_READAHEAD.MAX}` | `20` | Maksymalny procent stron odczytywanych przez read-ahead używany przez odpowiedni trigger/licznik. |
| `{$MSSQL.PERCENT_RECOMPILATIONS.MAX}` | `10` | Maksymalny procent rekompilacji Transact-SQL dla triggera. |
| `{$MSSQL.PORT}` | `1433` | Port TCP monitorowanej instancji SQL Server. |
| `{$MSSQL.QUORUM.MEMBER.DISCOVERY.NAME.MATCHES}` | `.*` | Filtr nazw członków quorum uwzględnianych przez discovery. |
| `{$MSSQL.QUORUM.MEMBER.DISCOVERY.NAME.NOT_MATCHES}` | `CHANGE_IF_NEEDED` | Filtr nazw członków quorum wykluczanych przez discovery. |
| `{$MSSQL.TCP.CRIT}` | `1` | Krytyczny próg czasu zestawienia połączenia TCP w sekundach; `1` oznacza 1000 ms. |
| `{$MSSQL.TCP.FAIL.COUNT}` | `#3` | Liczba kolejnych nieudanych próbek TCP wymagana do alertu niedostępności. |
| `{$MSSQL.TCP.RECOVERY.COUNT}` | `#2` | Liczba kolejnych udanych próbek TCP wymagana do uznania usługi za odzyskaną. |
| `{$MSSQL.TCP.WARN}` | `0.25` | Ostrzegawczy próg czasu zestawienia połączenia TCP w sekundach; `0.25` oznacza 250 ms. |
| `{$MSSQL.UPTIME.RESTART.WINDOW}` | `600` | Okno czasu w sekundach używane do wykrywania nieoczekiwanego restartu SQL Server. |
| `{$MSSQL.URI}` | `` | Identyfikator połączenia MSSQL. W naszym środowisku jest to nazwana sesja `SQL3`. |
| `{$MSSQL.USER}` | `` | Nazwa użytkownika MSSQL. Może pozostać pusta, gdy dane logowania są zapisane w nazwanej sesji Agent 2. |
| `{$MSSQL.WORKTABLES_FROM_CACHE_RATIO.MIN.CRIT}` | `90` | Minimalny procent work tables dostępnych z cache dla alertu wysokiego poziomu. |
| `{$MSSQL.WORK_FILES.MAX}` | `20` | Maksymalna liczba tworzonych work files na sekundę dla triggera. |
| `{$MSSQL.WORK_TABLES.MAX}` | `20` | Maksymalna liczba tworzonych work tables na sekundę dla triggera. |
