/* Read-only confirmation of the applied memory configuration. */
SELECT name, value, value_in_use
FROM sys.configurations
WHERE name IN (N'max server memory (MB)', N'min server memory (MB)');
SELECT cpu_count, scheduler_count,
       physical_memory_kb / 1024.0 AS SQLReportedPhysicalMemoryMB
FROM sys.dm_os_sys_info;
SELECT COUNT_BIG(*) AS BufferCount,
       CAST(COUNT_BIG(*) * 8.0 / 1024.0 AS decimal(18,2)) AS BufferPoolMB
FROM sys.dm_os_buffer_descriptors;
GO
