# DMVs (Dynamic Management Views/Functions) — SQL Server 2022

> **Cel:** szybkie odnajdywanie, rozumienie i użycie DMVs w kontekście katalogowych widoków (`sys.tables`, `sys.columns`), plus gotowe zapytania do typowych zadań diagnostycznych.

---

## 1. Krótkie wprowadzenie
Dynamic Management Views (DMVs) i Functions (DMFs) zwracają stan (telemetrię) instancji SQL Server / bazy danych — są podstawowym narzędziem do monitoringu, diagnostyki i tuningu. Są **in-memory** (stan zależny od bieżącej instancji) i nie zastępują katalogowych widoków, które przechowują metadata trwale.

> Uwaga: DMVs nie przechowują trwałych metadanych — po restarcie instancji zawartość niektórych DMVs (np. cache planów) jest tracona.

---

## 2. Jak szybko *odszukać* wszystkie DMVs na instancji / w bazie
### Lista wszystkich DMVs/DMFs (server-scoped + database-scoped):
```sql
-- Server-scoped i database-scoped (lista obiektów systemowych zaczynających się od "dm_")
SELECT name, type_desc
FROM sys.system_objects
WHERE name LIKE 'dm[_]%' 
ORDER BY name;
```

---

## 3. Kategorie DMVs (skrót) — najważniejsze grupy z typowymi DMVs

### A. Execution / Query / Plan
- `sys.dm_exec_requests` — aktywne requesty (co wykonuje się teraz).  
- `sys.dm_exec_sessions` — sesje klientów.  
- `sys.dm_exec_query_stats` — statystyki zapytań w cache planów.  
- `sys.dm_exec_sql_text(@sql_handle)` — DMF zwracająca tekst zapytania.  
- `sys.dm_exec_query_plan(@plan_handle)` — plan wykonania.

### B. Index / Storage / IO
- `sys.dm_db_index_physical_stats` — fizyczne właściwości i fragmentacja indeksów.  
- `sys.dm_db_index_usage_stats` — sposób użycia indeksów (seek/scan/update counts).  
- `sys.dm_io_virtual_file_stats` — IO per file.

### C. Buffer / Memory / Resource
- `sys.dm_os_buffer_descriptors` — zawartość buffer pool.  
- `sys.dm_os_memory_clerks`, `sys.dm_os_sys_memory` — informacje o pamięci.

### D. Waits / Blocking / Concurrency
- `sys.dm_os_wait_stats` — statystyki waitów.  
- `sys.dm_tran_locks` — aktywne locki.  
- `sys.dm_os_waiting_tasks` — zadania czekające (dobra do analiz blokad i waitów).

### E. Transaction / Log
- `sys.dm_tran_database_transactions`, `sys.dm_tran_active_transactions` — transakcje, status logów.

### F. IO / File / Database
- `sys.dm_db_file_space_usage` (DB scoped), `sys.dm_db_log_space_usage` — informacje o wykorzystaniu plików i logów.

### G. AlwaysOn / AG / Replication / Broker / Availability
- `sys.dm_hadr_database_replica_states` i inne DMV związane z Availability Groups i replikacją.

---

## 4. DMVs vs katalogowe widoki (`sys.tables`, `sys.columns`) — porównanie
- **`sys.tables`, `sys.columns` (catalog views)**  
  - Zawierają **trwałą** metadę: definicje tabel, kolumn, typów. Służą do pracy z DDL i schematem.

- **DMVs (np. `sys.dm_db_partition_stats`, `sys.dm_db_index_physical_stats`)**  
  - Zawierają stan operacyjny — rozmiary, statystyki w cache, użycie pamięci, fragmentację. Wiele DMVs łączy się z katalogami przez `object_id`, `index_id`, `partition_number`.

**W praktyce:** łączysz DMVs z katalogami aby uzyskać opisową i operacyjną perspektywę tej samej struktury.

---

## 5. Przydatne zapytania — mapowanie DMV ↔ `sys.tables` / `sys.columns`

### 5.1. Lista wszystkich DMVs (powtórka)
```sql
SELECT name, type_desc
FROM sys.system_objects
WHERE name LIKE 'dm[_]%' 
ORDER BY name;
```

### 5.2. Mapowanie: wielkość / liczba wierszy per tabela
```sql
SELECT 
  s.name AS schema_name,
  t.name AS table_name,
  p.index_id,
  p.partition_number,
  p.row_count,
  p.reserved_page_count,
  p.used_page_count
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.dm_db_partition_stats p ON p.object_id = t.object_id
WHERE t.is_ms_shipped = 0
ORDER BY s.name, t.name, p.index_id, p.partition_number;
```

### 5.3. Fragmentacja indeksów (łączone z katalogami)
```sql
SELECT 
  s.name AS schema_name,
  t.name AS table_name,
  i.name AS index_name,
  ips.index_type_desc,
  ips.index_level,
  ips.avg_fragmentation_in_percent,
  ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE ips.page_count > 50
ORDER BY ips.avg_fragmentation_in_percent DESC;
```

### 5.4. Które indeksy są używane (usage stats)
```sql
SELECT 
  DB_NAME(us.database_id) AS database_name,
  OBJECT_SCHEMA_NAME(us.object_id, us.database_id) AS schema_name,
  OBJECT_NAME(us.object_id, us.database_id) AS table_name,
  us.index_id,
  i.name AS index_name,
  us.user_seeks, us.user_scans, us.user_lookups, us.user_updates
FROM sys.dm_db_index_usage_stats us
LEFT JOIN sys.indexes i
  ON i.object_id = us.object_id AND i.index_id = us.index_id
WHERE us.database_id = DB_ID()
ORDER BY us.user_seeks DESC;
```

### 5.5. Mapowanie sesji → request → SQL text
```sql
SELECT
  s.session_id,
  s.login_name,
  r.status,
  r.command,
  r.cpu_time,
  r.total_elapsed_time,
  SUBSTRING(t.text, (r.statement_start_offset/2)+1,
    ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(t.text) ELSE r.statement_end_offset END
      - r.statement_start_offset)/2) + 1) AS current_statement,
  t.text AS full_batch
FROM sys.dm_exec_sessions s
LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE s.is_user_process = 1
ORDER BY r.total_elapsed_time DESC;
```

### 5.6. Top CPU-consuming plans (cache)
```sql
SELECT TOP 50
  qs.total_worker_time / qs.execution_count AS avg_cpu,
  qs.total_worker_time AS total_cpu,
  qs.execution_count,
  SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
    ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text) ELSE qs.statement_end_offset END
      - qs.statement_start_offset)/2) + 1) AS statement_text,
  qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY avg_cpu DESC;
```

### 5.7. Co siedzi w buffer pool (mapowanie do obiektów)
```sql
SELECT TOP 100
  COUNT(*) AS pages_in_cache,
  OBJECT_SCHEMA_NAME(p.object_id, p.database_id) AS schema_name,
  OBJECT_NAME(p.object_id, p.database_id) AS object_name,
  p.index_id,
  p.partition_number
FROM sys.dm_os_buffer_descriptors bd
JOIN sys.allocation_units au
  ON bd.allocation_unit_id = au.allocation_unit_id
LEFT JOIN sys.dm_db_partition_stats p
  ON au.container_id = p.hobt_id
WHERE bd.database_id = DB_ID()
GROUP BY OBJECT_SCHEMA_NAME(p.object_id, p.database_id), OBJECT_NAME(p.object_id, p.database_id), p.index_id, p.partition_number
ORDER BY pages_in_cache DESC;
```

> Uwaga: dołączenie `dm_os_buffer_descriptors` do allocation units/partitions wymaga odpowiednich uprawnień i może być zależne od kontekstu bazy.

---

## 6. Query-y pomocnicze — narzędzia

### 6.1. Lista DB-scoped DMVs
```sql
SELECT name 
FROM sys.system_objects
WHERE name LIKE 'dm_db_%' 
ORDER BY name;
```

### 6.2. Przykład: agregacja użycia indeksów i fragmentacji
```sql
SELECT 
  s.name, t.name,
  SUM(p.row_count) AS total_rows,
  SUM(p.reserved_page_count) AS reserved_pages,
  SUM(p.used_page_count) AS used_pages,
  AVG(ips.avg_fragmentation_in_percent) AS avg_fragmentation
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.dm_db_partition_stats p ON p.object_id = t.object_id
LEFT JOIN sys.dm_db_index_physical_stats(DB_ID(), t.object_id, NULL, NULL, 'LIMITED') ips
  ON ips.object_id = t.object_id
GROUP BY s.name, t.name
ORDER BY SUM(p.reserved_page_count) DESC;
```

---

## 7. Uprawnienia i bezpieczeństwo
- Do wielu DMVs wymagane są uprawnienia `VIEW SERVER STATE` (server-scoped DMVs) lub `VIEW DATABASE STATE` (database-scoped DMVs).
- Brak uprawnień skutkuje pustymi wynikami lub błędami. Upewnij się, że konto diagnostyczne ma odpowiednie prawa.

---

## 8. Przykładowy workflow: Zidentyfikuj wolne/ciężkie zapytania i zmapuj do tabel
1. Użyj `sys.dm_exec_query_stats` + `dm_exec_sql_text` żeby znaleźć top N zapytań CPU/IO.  
2. Dla konkretnego zapytania pobierz `plan_handle` i użyj `sys.dm_exec_query_plan` aby zobaczyć tabele używane w planie.  
3. Dla tabel użyj `sys.dm_db_partition_stats` / `sys.dm_db_index_physical_stats` by zweryfikować rozmiar / fragmentację / partycjonowanie.  
4. Sparuj to z `sys.indexes`, `sys.columns` żeby wiedzieć, które kolumny są skanowane lub używane w predicate'ach.

---

## 9. FAQ — krótkie odpowiedzi
**Q:** Czy DMVs zastępują `sys.tables` i `sys.columns`?  
**A:** Nie. DMVs dostarczają stanowy/operacyjny widok; katalogowe widoki dostarczają trwałe metadane. Zwykle łączysz je razem (np. `sys.tables` + `sys.dm_db_partition_stats`) aby uzyskać pełny obraz.

**Q:** Jak wymienić wszystkie DMVs na liście (pewność, że niczego nie przegapię)?  
**A:** Użyj `sys.system_objects` (patrz wyżej) lub oficjalnej listy MS Docs.

---

## 10. Przydatne linki (oficjalne)
- Dynamic management views (DMVs) — Microsoft Docs.  
- Index-related DMVs (lista) — Microsoft Docs.  
- `sys.dm_exec_requests` — Docs.  
- System catalog views — Docs (`sys.tables`, `sys.columns`).

---

_ostatnia aktualizacja: 2025-09-17
