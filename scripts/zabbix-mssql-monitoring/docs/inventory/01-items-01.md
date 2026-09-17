# Inwentarz — itemy instancji

Łącznie w szablonie: **139 itemów instancji**.

> Część 1 z 4 — podstawowe liczniki instancji.

Nazwy itemów i klucze pozostają zgodne z rzeczywistym szablonem Zabbixa. Kolumny „Sposób zbierania” i „Co mierzy / znaczenie” opisują mechanizm i interpretację po polsku.

| Nazwa | Klucz | Sposób zbierania | Co mierzy / znaczenie |
|---|---|---|---|
| Get Access Methods counters | `mssql.access_methods.raw` | item zależny od `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Surowe liczniki SQL Server z grupy Access Methods. Są źródłem m.in. dla full scans, index searches, page splits i lock escalations. |
| Auto-param attempts per second | `mssql.autoparam_attempts_sec.rate` | item zależny od `mssql.sql_statistics.raw` | Liczba prób automatycznej parametryzacji zapytań na sekundę. Suma powinna odpowiadać próbom failed, safe i unsafe. |
| Get availability groups | `mssql.availability.group.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → dodatek MSSQL | Pobiera stan Availability Groups: nazwę grupy, kondycję repliki primary i secondary oraz stan synchronizacji. |
| Average latch wait time | `mssql.average_latch_wait_time` | item obliczany z `mssql.average_latch_wait_time_raw` i wartości bazowej | Średni czas oczekiwania na latch w milisekundach dla żądań, które nie mogły zostać obsłużone natychmiast. |
| Average latch wait time base | `mssql.average_latch_wait_time_base` | item zależny od `mssql.latches_info.raw` | Wartość bazowa używana wewnętrznie do obliczenia średniego czasu oczekiwania na latch. |
| Average latch wait time raw | `mssql.average_latch_wait_time_raw` | item zależny od `mssql.latches_info.raw` | Surowa skumulowana wartość czasu oczekiwania na latch używana do wyliczenia średniej. |
| Total average wait time | `mssql.average_wait_time` | item obliczany z wartości `raw` i `base` | Średni czas oczekiwania na blokadę w milisekundach dla żądań blokad, które wymagały oczekiwania. |
| Total average wait time base | `mssql.average_wait_time_base` | item zależny od `mssql.locks_info.raw` | Wartość bazowa używana wewnętrznie do obliczenia średniego czasu oczekiwania na blokadę. |
| Total average wait time raw | `mssql.average_wait_time_raw` | item zależny od `mssql.locks_info.raw` | Surowa wartość czasu oczekiwania na blokady używana do obliczeń średniej. |
| Batch requests per second | `mssql.batch_requests_sec.rate` | item zależny od `mssql.sql_statistics.raw` | Liczba batchy Transact-SQL obsługiwanych na sekundę. Jest podstawową miarą przepustowości workloadu i zależy m.in. od CPU, I/O, pamięci i charakteru zapytań. |
| Buffer cache hit ratio | `mssql.buffer_cache_hit_ratio` | item zależny od `mssql.buffer_manager.raw` | Procent stron odnalezionych w buffer cache bez konieczności fizycznego odczytu z dysku. |
| Get Buffer Manager counters | `mssql.buffer_manager.raw` | item zależny od `mssql.perfcounter.get[...]` | Surowe liczniki Buffer Manager używane przez itemy związane z pamięcią, odczytami, zapisami i checkpointami. |
| Cache hit ratio | `mssql.cache_hit_ratio` | item zależny od `mssql.cache_info.raw` | Stosunek trafień w cache do liczby wyszukiwań w cache. |
| Get Cache counters | `mssql.cache_info.raw` | item zależny od `mssql.perfcounter.get[...]` | Surowe liczniki pamięci podręcznej SQL Server. |
| Cache objects in use | `mssql.cache_objects_in_use` | item zależny od `mssql.cache_info.raw` | Liczba obiektów cache aktualnie używanych przez SQL Server. |
| Cache object counts | `mssql.cache_object_counts` | item zależny od `mssql.cache_info.raw` | Łączna liczba obiektów znajdujących się w cache. |
| Cache pages | `mssql.cache_pages` | item zależny od `mssql.cache_info.raw` | Liczba stron 8 KB używanych przez obiekty cache. |
| Checkpoint pages per second | `mssql.checkpoint_pages_sec.rate` | item zależny od `mssql.buffer_manager.raw` | Liczba stron zapisywanych na dysk na sekundę przez checkpoint lub operację wymagającą opróżnienia dirty pages. |
| Database pages | `mssql.database_pages` | item zależny od `mssql.buffer_manager.raw` | Liczba stron w buffer pool zawierających dane baz użytkownika i systemowych. |
| Total data file size | `mssql.data_files_size` | item zależny od `mssql.db_info.raw` | Łączny rozmiar wszystkich plików danych raportowanych przez liczniki instancji. |
| Get database | `mssql.db.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → dodatek MSSQL | Pobiera listę baz danych wraz z informacjami wykorzystywanymi przez discovery, m.in. nazwą bazy i modelem odzyskiwania. |
| Get DB counters | `mssql.db_info.raw` | item zależny od `mssql.perfcounter.get[...]` | Surowe zbiorcze liczniki baz danych, źródło dla rozmiarów plików i liczby transakcji. |
| Total errors per second | `mssql.errors_sec.rate` | item zależny od `mssql.sql_errors.raw` | Łączna liczba błędów SQL Server na sekundę. |
| Failed auto-params per second | `mssql.failed_autoparams_sec.rate` | item zależny od `mssql.sql_statistics.raw` | Liczba nieudanych prób automatycznej parametryzacji na sekundę. W stabilnym środowisku powinna być niewielka. |
| Forwarded records per second | `mssql.forwarded_records_sec.rate` | item zależny od `mssql.access_methods.raw` | Liczba rekordów odczytywanych przez forwarded record pointers na sekundę. Wysokie wartości mogą wskazywać na częste przenoszenie rekordów w heapach. |
| Free list stalls per second | `mssql.free_list_stalls_sec.rate` | item zależny od `mssql.buffer_manager.raw` | Liczba żądań na sekundę, które musiały czekać na wolną stronę w buforze. Wzrost może wskazywać na presję pamięci. |
| Full scans per second | `mssql.full_scans_sec.rate` | item zależny od `mssql.access_methods.raw` | Liczba pełnych skanów tabel lub indeksów na sekundę. Wysokie wartości trzeba interpretować w kontekście workloadu, CPU i indeksów. |
| Get General Statistics counters | `mssql.general_statistics.raw` | item zależny od `mssql.perfcounter.get[...]` | Surowe liczniki General Statistics, m.in. połączenia i procesy zablokowane. |
| Granted Workspace Memory | `mssql.granted_workspace_memory` | item zależny od `mssql.mem_manager.raw` | Łączna ilość pamięci przyznanej aktualnie operatorom wymagającym memory grantów, np. sortowaniom, hash joinom, bulk copy i budowaniu indeksów. |
| Index searches per second | `mssql.index_searches_sec.rate` | item zależny od `mssql.access_methods.raw` | Liczba wyszukiwań w indeksach na sekundę, obejmująca m.in. rozpoczęcie range scan, pobranie pojedynczego rekordu i odnalezienie miejsca wstawienia w indeksie. |
| Errors per second (Info errors) | `mssql.info_errors_sec.rate` | item zależny od `mssql.sql_errors.raw` | Liczba błędów klasyfikowanych przez SQL Server jako informacyjne na sekundę. |
| Get job status | `mssql.job.status.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → dodatek MSSQL | Pobiera stan jobów SQL Server Agent; jest źródłem dla discovery jobów i ich statusów. |
| Errors per second (Kill connection errors) | `mssql.kill_connection_errors_sec.rate` | item zależny od `mssql.sql_errors.raw` | Liczba błędów na sekundę powodujących zakończenie połączenia. |
| Get last backup | `mssql.last.backup.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → dodatek MSSQL | Pobiera informacje o ostatnich backupach baz danych i jest źródłem dla monitoringu SLA backupów. |
| Get Latches counters | `mssql.latches_info.raw` | item zależny od `mssql.perfcounter.get[...]` | Surowe liczniki latchy SQL Server. |
| Latch waits per second | `mssql.latch_waits_sec.rate` | item zależny od `mssql.latches_info.raw` | Liczba żądań latch na sekundę, których nie można było przyznać natychmiast. Latch jest lekkim mechanizmem synchronizacji zasobów wewnętrznych SQL Server. |
| Lazy writes per second | `mssql.lazy_writes_sec.rate` | item zależny od `mssql.buffer_manager.raw` | Liczba buforów zapisywanych na sekundę przez lazy writera. Trwale wysokie wartości mogą wskazywać na presję pamięci lub intensywny churn w buffer pool. |
| Get local DB | `mssql.local.db.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → dodatek MSSQL | Pobiera stan lokalnych baz należących do Availability Groups. |
| Get Locks counters | `mssql.locks_info.raw` | item zależny od `mssql.perfcounter.get[...]` | Surowe liczniki blokad SQL Server używane do obliczenia lock requests, waits, timeouts i średnich czasów oczekiwania. |
| Total lock requests per second | `mssql.lock_requests_sec.rate` | item zależny od `mssql.locks_info.raw` | Liczba nowych żądań blokad i konwersji blokad na sekundę. |
| Total lock requests per second that timed out | `mssql.lock_timeouts_sec.rate` | item zależny od `mssql.locks_info.raw` | Liczba żądań blokad na sekundę zakończonych timeoutem, łącznie z żądaniami `NOWAIT`. |
| Total lock requests per second that required waiting | `mssql.lock_waits_sec.rate` | item zależny od `mssql.locks_info.raw` | Liczba żądań blokad na sekundę, które wymagały oczekiwania. |
| Lock wait time | `mssql.lock_wait_time` | item zależny od `mssql.locks_info.raw` | Średni czas oczekiwania na blokady w ostatnim interwale, wyrażony w milisekundach. |
| Logins per second | `mssql.logins_sec.rate` | item zależny od `mssql.general_statistics.raw` | Liczba nowych logowań do SQL Server na sekundę, bez połączeń pobranych z puli. Trwale wysokie wartości mogą wskazywać na niewłaściwe wykorzystanie connection poolingu. |
| Logouts per second | `mssql.logouts_sec.rate` | item zależny od `mssql.general_statistics.raw` | Liczba wylogowań z SQL Server na sekundę. Razem z loginami pomaga ocenić churn połączeń i efektywność connection poolingu. |
