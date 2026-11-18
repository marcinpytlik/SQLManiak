/* Buffer Pool Scan Research Lab — diagnostyka tylko do odczytu */
SET NOCOUNT ON;
SELECT @@VERSION AS SQLVersion, SYSDATETIMEOFFSET() AS CapturedAt;
SELECT cpu_count, scheduler_count, physical_memory_kb / 1024.0 AS PhysicalMemoryMB
FROM sys.dm_os_sys_info;
SELECT name, value_in_use
FROM sys.configurations WHERE name IN ('max server memory (MB)', 'min server memory (MB)');
SELECT COUNT(*) AS VisibleOnlineSchedulers FROM sys.dm_os_schedulers
WHERE status = 'VISIBLE ONLINE';
SELECT COUNT_BIG(*) AS BufferCount,
       CAST(COUNT_BIG(*) * 8.0 / 1024.0 AS decimal(18,2)) AS BufferPoolMB
FROM sys.dm_os_buffer_descriptors;
SELECT name, description FROM sys.dm_xe_objects
WHERE object_type = 'event' AND name LIKE '%buffer_pool_scan%';
SELECT object_name, name, type_name, column_type
FROM sys.dm_xe_object_columns
WHERE object_name = 'buffer_pool_scan_complete' ORDER BY column_id;
