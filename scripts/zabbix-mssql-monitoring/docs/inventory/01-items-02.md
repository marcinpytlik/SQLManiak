# Inwentarz — itemy instancji

Łącznie w szablonie: **139 itemów instancji**.

> Część 2 z 4 — pamięć, blokady, transakcje i pozostałe liczniki.

| Nazwa | Klucz | Sposób zbierania | Co mierzy / znaczenie |
|---|---|---|---|
| Total log file size | `mssql.log_files_size` | item zależny od `mssql.db_info.raw` | Łączny rozmiar wszystkich plików logu transakcyjnego raportowanych przez liczniki SQL Server. |
| Total log file used size | `mssql.log_files_used_size` | item zależny od `mssql.db_info.raw` | Łączna zajęta przestrzeń plików logu transakcyjnego. |
| Maximum workspace memory | `mssql.maximum_workspace_memory` | item zależny od `mssql.mem_manager.raw` | Maksymalna ilość pamięci dostępnej dla operatorów wymagających memory grantów, np. hash, sort, bulk copy i tworzenie indeksów. |
| Memory grants outstanding | `mssql.memory_grants_outstanding` | item zależny od `mssql.mem_manager.raw` | Liczba procesów, które aktualnie otrzymały memory grant. |
| Memory grants pending | `mssql.memory_grants_pending` | item zależny od `mssql.mem_manager.raw` | Liczba procesów oczekujących na przyznanie memory grantu. Wartość większa od zera może wskazywać na presję pamięci dla zapytań. |
| Get Memory counters | `mssql.mem_manager.raw` | item zależny od `mssql.perfcounter.get[...]` | Surowe liczniki Memory Manager używane przez itemy związane z pamięcią serwera i memory grantami. |
| Get DB mirroring | `mssql.mirroring.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → dodatek MSSQL | Pobiera informacje o Database Mirroring. |
| Get non-local DB | `mssql.nonlocal.db.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → dodatek MSSQL | Pobiera stan baz Availability Group, dla których monitorowana instancja nie jest lokalnym właścicielem danej kopii. |
| Total lock requests per second that have deadlocks | `mssql.number_deadlocks_sec.rate` | item zależny od `mssql.locks_info.raw` | Liczba żądań blokad na sekundę zakończonych deadlockiem. |
| Errors per second (DB offline errors) | `mssql.offline_errors_sec.rate` | item zależny od `mssql.sql_errors.raw` | Liczba błędów na sekundę związanych z bazami w stanie offline. |
| Page life expectancy | `mssql.page_life_expectancy` | item zależny od `mssql.buffer_manager.raw` | Szacowana liczba sekund, przez które strona pozostaje w buffer pool bez ponownego odwołania. Spadek może wskazywać na presję pamięci, ale wymaga interpretacji w kontekście workloadu. |
| Page lookups per second | `mssql.page_lookups_sec.rate` | item zależny od `mssql.buffer_manager.raw` | Liczba żądań wyszukania strony w buffer pool na sekundę. |
| Page reads per second | `mssql.page_reads_sec.rate` | item zależny od `mssql.buffer_manager.raw` | Liczba fizycznych odczytów stron baz danych na sekundę. Pomaga ocenić zależność workloadu od fizycznego I/O. |
| Page splits per second | `mssql.page_splits_sec.rate` | item zależny od `mssql.access_methods.raw` | Liczba podziałów stron indeksów na sekundę. Wysokie wartości mogą wskazywać m.in. na niekorzystny fill factor lub charakter wzrostu kluczy. |
| Page writes per second | `mssql.page_writes_sec.rate` | item zależny od `mssql.buffer_manager.raw` | Liczba fizycznych zapisów stron baz danych na sekundę. |
| Percent of ad hoc queries running | `mssql.percent_of_adhoc_queries` | item obliczany z compilations/sec i batch requests/sec | Stosunek liczby kompilacji SQL do liczby batchy, wyrażony procentowo. Pomaga ocenić udział workloadu generującego nowe plany. |
| Percent of Recompiled Transact-SQL Objects | `mssql.percent_recompilations_to_compilations` | item obliczany z recompilations/sec i compilations/sec | Procentowy udział rekompilacji w całkowitej liczbie kompilacji. Trwale wysoki udział wymaga diagnostyki przyczyn rekompilacji. |
| Get performance counters | `mssql.perfcounter.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → dodatek MSSQL | Główny surowy zestaw liczników wydajności SQL Server używany przez wiele itemów zależnych. |
| Number of blocked processes | `mssql.processes_blocked` | item zależny od `mssql.general_statistics.raw` | Aktualna liczba procesów zablokowanych przez inne sesje. Sam licznik jest objawem; interpretujemy go razem z lock waits, timeouts i czasem oczekiwania. |
| Get quorum | `mssql.quorum.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → dodatek MSSQL | Pobiera nazwę klastra, typ quorum i jego stan. |
| Get quorum member | `mssql.quorum.member.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → dodatek MSSQL | Pobiera członków quorum, ich typ, stan i liczbę głosów. |
| Read-ahead pages per second | `mssql.readahead_pages_sec.rate` | item zależny od `mssql.buffer_manager.raw` | Liczba stron odczytywanych z wyprzedzeniem na sekundę przez mechanizm read-ahead. |
| Get replica | `mssql.replica.get["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → dodatek MSSQL | Pobiera informacje o replikach baz danych w Availability Groups. |
| Safe auto-params per second | `mssql.safe_autoparams_sec.rate` | item zależny od `mssql.sql_statistics.raw` | Liczba bezpiecznych prób automatycznej parametryzacji na sekundę, dla których plan może być współdzielony między podobnymi zapytaniami. |
| Full scans to Index searches ratio | `mssql.scan_to_search` | item obliczany z `full_scans_sec` i `index_searches_sec` | Stosunek pełnych skanów do wyszukiwań indeksowych. Wartość interpretujemy zależnie od typu workloadu; progi typowe dla OLTP nie muszą pasować do hurtowni. |
| SQL compilations per second | `mssql.sql_compilations_sec.rate` | item zależny od `mssql.sql_statistics.raw` | Liczba kompilacji SQL na sekundę. Pomaga ocenić koszt tworzenia planów i skuteczność ponownego użycia planów z cache. |
| Get SQL Errors counters | `mssql.sql_errors.raw` | item zależny od `mssql.perfcounter.get[...]` | Surowe liczniki błędów SQL Server. |
| SQL re-compilations per second | `mssql.sql_recompilations_sec.rate` | item zależny od `mssql.sql_statistics.raw` | Liczba rekompilacji instrukcji na sekundę. Wysokie wartości mogą wskazywać na niestabilność planów lub częste zmiany warunków kompilacji. |
| Get SQL Statistics counters | `mssql.sql_statistics.raw` | item zależny od `mssql.perfcounter.get[...]` | Surowe liczniki SQL Statistics używane m.in. dla batch requests, compilations i recompilations. |
| Table lock escalations per second | `mssql.table_lock_escalations.rate` | item zależny od `mssql.access_methods.raw` | Liczba eskalacji blokad do poziomu TABLE lub HoBT na sekundę. |
| Target pages | `mssql.target_pages` | item zależny od `mssql.buffer_manager.raw` | Docelowa liczba stron, które SQL Server chciałby utrzymywać w buffer pool. |
| Target server memory | `mssql.target_server_memory` | item zależny od `mssql.mem_manager.raw` | Docelowa ilość pamięci, którą SQL Server chciałby wykorzystać zgodnie z aktualnymi warunkami i konfiguracją. |
| Total latch wait time | `mssql.total_latch_wait_time` | item zależny od `mssql.latches_info.raw` | Łączny czas oczekiwania na latch w ostatnim interwale. Należy analizować razem z liczbą latch waits. |
| Total server memory | `mssql.total_server_memory` | item zależny od `mssql.mem_manager.raw` | Ilość pamięci aktualnie zaangażowanej przez SQL Server poprzez memory manager. |
| Total transactions number | `mssql.transactions` | item zależny od `mssql.perfcounter.get[...]` | Aktualna liczba aktywnych transakcji wszystkich typów. |
| Total transactions per second | `mssql.transactions_sec.rate` | item zależny od `mssql.db_info.raw` | Łączna liczba transakcji rozpoczynanych na sekundę we wszystkich bazach. |
| Unsafe auto-params per second | `mssql.unsafe_autoparams_sec.rate` | item zależny od `mssql.sql_statistics.raw` | Liczba prób automatycznej parametryzacji uznanych za unsafe, czyli takich, dla których plan nie może być bezpiecznie współdzielony. |
| Uptime | `mssql.uptime` | item zależny od `mssql.perfcounter.get[...]` | Czas działania SQL Server. Może służyć m.in. do wykrywania nieoczekiwanych restartów. |
| Number of users connected | `mssql.user_connections` | item zależny od `mssql.general_statistics.raw` | Aktualna liczba połączeń użytkowników do SQL Server. |
| Errors per second (User errors) | `mssql.user_errors_sec.rate` | item zależny od `mssql.sql_errors.raw` | Liczba błędów użytkownika raportowanych na sekundę. |
| Version | `mssql.version["{$MSSQL.URI}","{$MSSQL.USER}","{$MSSQL.PASSWORD}"]` | Agent 2 → dodatek MSSQL | Wersja monitorowanego SQL Server. |
| Work files created per second | `mssql.workfiles_created_sec.rate` | item zależny od `mssql.access_methods.raw` | Liczba work files tworzonych na sekundę, np. dla hash joinów i hash aggregates. Wysokie wartości mogą korelować z intensywnym użyciem tempdb. |
| Work tables created per second | `mssql.worktables_created_sec.rate` | item zależny od `mssql.access_methods.raw` | Liczba work tables tworzonych na sekundę, np. dla spool, zmiennych LOB/XML i kursorów. |
| Worktables from cache ratio | `mssql.worktables_from_cache_ratio` | item zależny od `mssql.access_methods.raw` | Procent work tables, których początkowe strony były dostępne z cache zamiast wymagać ponownej alokacji. |
| Service's TCP port state | `net.tcp.service[tcp,{$MSSQL.HOST},{$MSSQL.PORT}]` | prosty test TCP Zabbixa | Sprawdza dostępność usługi SQL Server na skonfigurowanym porcie TCP. |
