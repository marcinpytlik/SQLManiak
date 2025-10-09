-- Kto gdzie wpada?
SELECT s.session_id, s.login_name, s.host_name, s.program_name,
       DB_NAME(s.database_id) AS dbname,
       wg.name AS workload_group, rp.name AS pool_name
FROM sys.dm_exec_sessions s
JOIN sys.dm_resource_governor_workload_groups wg ON s.group_id = wg.group_id
JOIN sys.dm_resource_governor_resource_pools  rp ON wg.pool_id = rp.pool_id
WHERE s.is_user_process = 1
ORDER BY s.session_id;

-- Parametry pooli
SELECT name, cap_cpu_percent, min_iops_per_volume, max_iops_per_volume
FROM sys.resource_governor_resource_pools
WHERE name IN (N'pool_lab_noisy', N'pool_prod_friendly');

-- Parametry grup
SELECT name, importance, max_dop,
       request_max_memory_grant_percent, request_min_memory_grant_percent,
       request_memory_grant_timeout_sec, group_max_requests
FROM sys.resource_governor_workload_groups
WHERE name IN (N'wg_lab_noisy', N'wg_prod_friendly');

-- Obciążenie I/O plików (na szybko)
SELECT DB_NAME(vfs.database_id) AS dbname,
       mf.type_desc AS file_type,
       mf.physical_name,
       vfs.num_of_reads, vfs.num_of_writes,
       vfs.io_stall_read_ms, vfs.io_stall_write_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
JOIN sys.master_files AS mf
  ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
ORDER BY (vfs.num_of_reads + vfs.num_of_writes) DESC;
