Quick Reference Handbook
---

## 📜 Skrypt: pełna lista DMV

Aby wygenerować pełną listę dynamicznych widoków zarządzania (DMV) w instancji SQL Server wraz z kategorią i linkami do dokumentacji Microsoft, użyj skryptu:

[scripts/list_dmvs.sql](../scripts/list_dmvs.sql). Poniżej krótki opis widoków jakie mam u siebie w wersji SQL Server. Widoki różnią się między wersjami SQL Server.

 – 🖥️ OS / SQLOS (sys.dm_*)


sys.dm_os_sys_info — metryki instancji i środowiska, rdzenie, czas działania.

sys.dm_os_host_info — wersja/edycja Windows i środowisko hosta.

sys.dm_os_sys_memory — pamięć z perspektywy systemu operacyjnego.

sys.dm_os_process_memory — użycie pamięci przez proces SQL Server.

sys.dm_os_memory_clerks — konsumpcja pamięci przez poszczególne komponenty.

sys.dm_os_memory_nodes — wykorzystanie pamięci per NUMA node.

sys.dm_os_memory_objects — obiekty pamięciowe i ich rozmiary.

sys.dm_os_memory_cache_counters — statystyki cache store’ów.

sys.dm_os_schedulers — schedulery SQLOS, stan i obciążenie CPU.

sys.dm_os_workers — wątki workers i ich stan.

sys.dm_os_tasks — zadania obsługiwane przez workers/schedulers.

sys.dm_os_wait_stats — zagregowane statystyki oczekiwań.

sys.dm_os_waiting_tasks — aktualnie czekające taski.

sys.dm_os_latch_stats — statystyki latchy.

sys.dm_os_spinlock_stats — spinlocki (zaawansowane).

sys.dm_os_buffer_descriptors — strony w buffer pool (baza, plik).

sys.dm_os_buffer_pool_extension_configuration — konfiguracja BPE (SSD overflow).

sys.dm_os_performance_counters — wbudowany perfmon.

sys.dm_os_ring_buffers — zdarzenia wewnętrzne w ring buffer.

sys.dm_os_loaded_modules — załadowane DLL w procesie.

sys.dm_os_cluster_nodes / sys.dm_os_cluster_properties — metadane klastra WSFC.

sys.dm_os_windows_info — wersja kompilacji Windows.

sys.dm_os_nodes — węzły NUMA widziane przez SQLOS.

⚡ Execution / Requests / Cache (sys.dm_exec_*)

sys.dm_exec_sessions — aktywne sesje.

sys.dm_exec_connections — połączenia sieciowe.

sys.dm_exec_requests — aktualne żądania.

sys.dm_exec_cached_plans — cache planów.

sys.dm_exec_query_stats — statystyki zapytań.

sys.dm_exec_procedure_stats — statystyki procedur.

sys.dm_exec_trigger_stats — statystyki triggerów.

sys.dm_exec_query_memory_grants — przydziały pamięci zapytań.

sys.dm_exec_query_resource_semaphores — semafory pamięci.

sys.dm_exec_session_wait_stats — waity per sesja.

sys.dm_exec_query_optimizer_info — wskaźniki optymalizatora.

📂 Database / Indexes / Space (sys.dm_db_*)

sys.dm_db_index_usage_stats — użycie indeksów.

sys.dm_db_partition_stats — rozmiar partycji.

sys.dm_db_file_space_usage — wykorzystanie plików tempdb.

sys.dm_db_session_space_usage — tempdb per sesja.

sys.dm_db_task_space_usage — tempdb per task.

sys.dm_db_missing_index_details / _groups / _group_stats — brakujące indeksy.

sys.dm_db_persisted_sku_features — funkcje wymagające konkretnej edycji.

sys.dm_db_sequence_object_stats — użycie obiektów SEQUENCE.

sys.dm_db_column_store_row_group_physical_stats — row-group columnstore.

sys.dm_db_xtp_memory_consumers — In-Memory OLTP: pamięć.

sys.dm_db_xtp_checkpoint_files — checkpointy XTP.

sys.dm_db_xtp_hash_index_stats / _index_stats — indeksy XTP.

sys.dm_db_xtp_table_memory_stats — pamięć tabel in-memory.

ℹ️ Wiele narzędziowych pereł to DMF (np. sys.dm_db_index_physical_stats, sys.dm_db_log_stats, sys.dm_db_page_info) — to funkcje, nie widoki.

💾 I/O (sys.dm_io_*)

sys.dm_io_pending_io_requests — oczekujące I/O.

🔒 Transactions / Locks / Versioning (sys.dm_tran_*)

sys.dm_tran_locks — blokady.

sys.dm_tran_active_transactions — aktywne transakcje.

sys.dm_tran_current_transaction — bieżąca transakcja sesji.

sys.dm_tran_database_transactions — transakcje powiązane z bazami.

sys.dm_tran_session_transactions — powiązanie sesja ↔ transakcja.

sys.dm_tran_top_version_generators — top twórcy wersji (RCSI/SI).

sys.dm_tran_version_store — rekordy w version store.

🎯 Extended Events (sys.dm_xe_*)

sys.dm_xe_sessions — sesje XE.

sys.dm_xe_session_targets — targets w sesjach XE.

sys.dm_xe_objects — obiekty XE (eventy, akcje).

sys.dm_xe_packages — pakiety XE.

sys.dm_xe_map_values — mapowania enum.

sys.dm_xe_object_columns — kolumny obiektów XE.

sys.dm_xe_session_event_actions — akcje w sesjach.

🔄 Always On / HADR (sys.dm_hadr_*)

sys.dm_hadr_availability_group_states — stan AG.

sys.dm_hadr_availability_replica_states — stan replik.

sys.dm_hadr_database_replica_states — stan baz na replikach.

sys.dm_hadr_auto_page_repair — auto-naprawy stron.

sys.dm_hadr_cluster / _members / _networks — metadane WSFC z perspektywy AG.

⚙️ Resource Governor (sys.dm_resource_governor_*)

sys.dm_resource_governor_configuration — konfiguracja RG.

sys.dm_resource_governor_resource_pools / _stats / _affinity — pule zasobów.

sys.dm_resource_governor_workload_groups / _stats — grupy obciążeń.

sys.dm_resource_governor_external_resource_pools / _stats / _affinity — pule external scripts.

sys.dm_resource_governor_external_workload_groups / _stats — grupy external WG.

✉️ Service Broker (sys.dm_broker_*)

sys.dm_broker_activated_tasks — aktywowane zadania.

sys.dm_broker_connections — połączenia.

sys.dm_broker_forwarded_messages — wiadomości przekazywane.

sys.dm_broker_queue_monitors — monitory kolejek.

sys.dm_broker_transmission_queue — kolejka transmisji.

🧩 CLR (sys.dm_clr_*)

sys.dm_clr_appdomains — domeny CLR.

sys.dm_clr_loaded_assemblies — assemblies.

sys.dm_clr_tasks — zadania CLR.

🔍 Full-Text Search (sys.dm_fts_*)

sys.dm_fts_active_catalogs — aktywne katalogi.

sys.dm_fts_memory_buffers — bufory FTS.

sys.dm_fts_population_ranges — zakresy populacji.

sys.dm_fts_index_keywords / _by_document — słowa kluczowe.

🖧 Server / Audit / Usługi (sys.dm_server_*)

sys.dm_server_audit_status — status audytu.

sys.dm_server_services — usługi instancji (konto, stan, ścieżka).

sys.dm_server_memory_dumps — zrzuty pamięci.

🔄 Change Data Capture (sys.dm_cdc_*)

sys.dm_cdc_errors — błędy CDC.

sys.dm_cdc_log_scan_sessions — sesje skanowania logu.

📡 Replication (sys.dm_repl_*)

sys.dm_repl_traninfo — transakcje w replikacji transakcyjnej.