-- scripts/01_setup.sql
-- Raport bieżącej konfiguracji tempdb oraz stan waitów/latchy.

-- 1) Konfiguracja plików tempdb
SELECT name, type_desc, size*8/1024 AS size_MB, growth*8/1024 AS growth_MB, max_size, physical_name
FROM tempdb.sys.database_files
ORDER BY file_id;

-- 2) Opcje autogrowth all files
SELECT name, is_autogrow_all_files
FROM sys.databases
WHERE name = 'tempdb';

-- 3) Bieżące waity związane z tempdb
SELECT TOP (50)
    ws.wait_type, ws.waiting_tasks_count, ws.wait_time_ms, ws.signal_wait_time_ms
FROM sys.dm_os_wait_stats AS ws
WHERE ws.wait_type LIKE 'PAGELATCH%'
ORDER BY ws.wait_time_ms DESC;

-- 4) Strony alokacyjne w tempdb (PFS/GAM/SGAM/IAM) - identyfikacja
DBCC IND(tempdb, 'sysallocunits', -1); -- lista stron, podgląd struktury

-- 5) Opcjonalnie: wymuszenie AUTOGROW_ALL_FILES (dla tempdb)
-- ALTER DATABASE tempdb MODIFY FILEGROUP [PRIMARY] AUTOGROW_ALL_FILES;
-- GO
