# Sessions and Workers in SQL Server

## 1. Podgląd aktywnych sesji
```sql
SELECT 
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    s.status,
    s.open_transaction_count,
    s.reads, s.writes, s.cpu_time, s.memory_usage,
    c.net_transport, c.protocol_type, c.client_net_address
FROM sys.dm_exec_sessions s
LEFT JOIN sys.dm_exec_connections c
    ON s.session_id = c.session_id
WHERE s.is_user_process = 1;
```

## 2. Podgląd aktywnych requestów w ramach sesji
```sql
SELECT 
    r.session_id,
    r.request_id,
    r.start_time,
    r.status,
    r.command,
    r.cpu_time,
    r.total_elapsed_time,
    t.text AS sql_text
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
ORDER BY r.session_id, r.request_id;
```

## 3. Dlaczego sesja może mieć wiele workerów?
- **Równoległość (parallelism)** → jedno zapytanie może uruchomić wiele wątków (workers).
- **MARS (Multiple Active Result Sets)** → przy włączonym MARS, jedna sesja może mieć kilka aktywnych zapytań.
- **Zadania wewnętrzne** → np. deferred compile, operacje tła.
- **Transakcje** → sesja trzyma locki, ale dodatkowe worker’y wykonują inne operacje.

## 4. Demo: równoległość
```sql
-- Wymuszenie równoległości w planie zapytania
DBCC FREEPROCCACHE;
GO
SELECT COUNT(*)
FROM sys.objects a
CROSS JOIN sys.objects b
CROSS JOIN sys.objects c
OPTION (MAXDOP 8);
```

W czasie wykonywania tego zapytania sprawdź DMV:
```sql
SELECT r.session_id, r.request_id, r.scheduler_id, r.status, t.text
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id > 50;
```
Zobaczysz jedną sesję z wieloma workerami (różne schedulery).

---
✅ **Ćwiczenie praktyczne**:  
1. Uruchom zapytanie z sekcji "Demo".  
2. W drugim oknie odpal DMV dla `sys.dm_exec_requests`.  
3. Zanotuj różnicę między `session_id` (jedna) a `request_id`/`scheduler_id` (wiele).  
