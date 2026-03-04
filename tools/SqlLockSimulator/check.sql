-- Jak to sprawdzić szybko na SQL Server
--1) Znajdź sesje z otwartą transakcją i blokowaniem
SELECT
    r.session_id,
    r.blocking_session_id,
    r.status,
    r.wait_type,
    r.wait_time,
    r.command,
    DB_NAME(r.database_id) AS dbname,
    s.login_name,
    s.host_name,
    s.program_name,
    t.text AS sql_text
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id <> 0
   OR r.session_id IN (SELECT blocking_session_id FROM sys.dm_exec_requests WHERE blocking_session_id <> 0)
ORDER BY r.blocking_session_id DESC, r.session_id;
--2) Najstarsza otwarta transakcja w bazie
DBCC OPENTRAN;
--3) Kto trzyma locki (w tym XLOCK)
SELECT
    tl.request_session_id,
    tl.resource_type,
    tl.request_mode,
    tl.request_status,
    tl.resource_description
FROM sys.dm_tran_locks tl
WHERE tl.request_mode IN ('X', 'IX')
ORDER BY tl.request_session_id;
--4) Czy sesja “żyje” ale nic nie robi (typowe przy aplikacji, która padła)
SELECT
    s.session_id,
    s.status,
    s.last_request_start_time,
    s.last_request_end_time,
    s.open_transaction_count,
    s.host_name,
    s.program_name,
    s.login_name
FROM sys.dm_exec_sessions s
WHERE s.open_transaction_count > 0
ORDER BY s.last_request_start_time;
-- podejrzane są sesje z open_transaction_count > 0 i brak aktywnego requestu (status = sleeping)
-- → często oznacza: aplikacja utknęła / nie domknęła transakcji.
--Jak sprawdzić, czy to “memory pressure” na SQL

Szybki rzut oka:

SELECT
    total_physical_memory_kb/1024 AS total_mem_mb,
    available_physical_memory_kb/1024 AS avail_mem_mb,
    system_memory_state_desc
FROM sys.dm_os_sys_memory;

SELECT
    physical_memory_in_use_kb/1024 AS sql_mem_in_use_mb,
    locked_page_allocations_kb/1024 AS locked_pages_mb,
    total_virtual_address_space_kb/1024 AS vmem_total_mb,
    available_virtual_address_space_kb/1024 AS vmem_avail_mb,
    process_physical_memory_low,
    process_virtual_memory_low
FROM sys.dm_os_process_memory;
