/*=====================================================================
  File:        BufferPool_Audit.sql
  Purpose:     One-stop script to inspect Buffer Pool, Memory Clerks,
               Page Life Expectancy and related memory components.
    Requirements:
    - Permissions: VIEW SERVER STATE (or sysadmin)
    - Tested on: SQL Server 2016–2022
  Notes:
    - Page size = 8 KB
    - This script is read-only (does NOT clear caches).
    - Run in any database (some sections filter to current DB; adjust WHERE as needed).
=====================================================================*/

/*=====================================================================
  0) Session info & environment
=====================================================================*/
SET NOCOUNT ON;
DECLARE @ts DATETIME2(0) = SYSDATETIME();
PRINT 'BufferPool_Audit started at ' + CONVERT(varchar(19), @ts, 120);
PRINT @@SERVERNAME + ' | ' + CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(50)) + ' | ' + CAST(SERVERPROPERTY('Edition') AS nvarchar(100));

SELECT
    @@SERVERNAME                AS [ServerName],
    SERVERPROPERTY('MachineName') AS [MachineName],
    CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(50)) AS [ProductVersion],
    CAST(SERVERPROPERTY('ProductLevel')   AS nvarchar(50)) AS [ProductLevel],
    CAST(SERVERPROPERTY('Edition')        AS nvarchar(100)) AS [Edition],
    CAST(SERVERPROPERTY('EngineEdition')  AS nvarchar(50)) AS [EngineEdition],
    sqlserver_start_time        AS [SQLStartTime],
    SYSDATETIME()               AS [CollectedAt]
FROM sys.dm_os_sys_info;

/*=====================================================================
  1) Buffer Pool by database (pages / MB / modified pages)
=====================================================================*/
PRINT '1) Buffer Pool by database';
SELECT
    DB_NAME(database_id)                            AS DatabaseName,
    COUNT(*)                                        AS Pages,
    ROUND(COUNT(*) * 8.0 / 1024, 2)                 AS MB_in_BufferPool,
    SUM(CASE WHEN is_modified = 1 THEN 1 ELSE 0 END) AS ModifiedPages,
    CAST(100.0 * SUM(CASE WHEN is_modified = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS decimal(5,2)) AS ModifiedPct
FROM sys.dm_os_buffer_descriptors WITH (NOLOCK)
GROUP BY database_id
ORDER BY MB_in_BufferPool DESC;

/*=====================================================================
  2) Buffer Pool page types per database
=====================================================================*/
PRINT '2) Buffer Pool page types per database';
SELECT
    DB_NAME(database_id)            AS DatabaseName,
    page_type,
    COUNT(*)                        AS Pages,
    ROUND(COUNT(*) * 8.0 / 1024, 2) AS MB
FROM sys.dm_os_buffer_descriptors WITH (NOLOCK)
GROUP BY database_id, page_type
ORDER BY DatabaseName, Pages DESC;

/*=====================================================================
  3) Top objects (tables/indexes) in Buffer Pool (current DB by default)
     - Remove/adjust WHERE b.database_id = DB_ID() to see all databases
=====================================================================*/
PRINT '3) Top objects in Buffer Pool (current DB)';
SELECT TOP(50)
    DB_NAME(b.database_id)                               AS [Database],
    ISNULL(SCHEMA_NAME(o.schema_id), '---')              AS [Schema],
    ISNULL(o.name, '<<heap or allocation without object>>') AS [ObjectName],
    p.index_id,
    p.partition_number,
    COUNT(*)                                             AS Pages,
    ROUND(COUNT(*) * 8.0 / 1024, 2)                      AS MB
FROM sys.dm_os_buffer_descriptors AS b WITH (NOLOCK)
LEFT JOIN sys.allocation_units AS au
    ON b.allocation_unit_id = au.allocation_unit_id
LEFT JOIN sys.partitions AS p
    ON au.container_id = p.hobt_id
LEFT JOIN sys.objects AS o
    ON p.object_id = o.object_id
WHERE b.database_id = DB_ID()   -- <== change/remove to widen scope
GROUP BY DB_NAME(b.database_id), SCHEMA_NAME(o.schema_id), o.name, p.index_id, p.partition_number
ORDER BY Pages DESC;

/*=====================================================================
  4) Buffer Pool by file (hot files)
=====================================================================*/
PRINT '4) Buffer Pool by file';
SELECT
    DB_NAME(database_id)            AS [Database],
    file_id,
    COUNT(*)                        AS Pages,
    ROUND(COUNT(*) * 8.0 / 1024, 2) AS MB
FROM sys.dm_os_buffer_descriptors WITH (NOLOCK)
GROUP BY database_id, file_id
ORDER BY MB DESC;

/*=====================================================================
  5) Sample of pages for a specific object (current DB)
     - Change @ObjectName to your table/view/clustered index parent
     - Use output file_id/page_id to inspect with DBCC PAGE (section 9)
=====================================================================*/
DECLARE @ObjectName sysname = N''; -- e.g. N'YourTableName'
IF (@ObjectName IS NOT NULL AND @ObjectName <> N'')
BEGIN
    PRINT '5) Sample pages for object: ' + @ObjectName;
    SELECT TOP(200)
        b.database_id,
        DB_NAME(b.database_id) AS DBName,
        b.file_id,
        b.page_id,
        b.page_type,
        b.is_modified,
        au.allocation_unit_id,
        o.name AS ObjectName,
        p.index_id
    FROM sys.dm_os_buffer_descriptors AS b WITH (NOLOCK)
    LEFT JOIN sys.allocation_units AS au ON b.allocation_unit_id = au.allocation_unit_id
    LEFT JOIN sys.partitions AS p ON au.container_id = p.hobt_id
    LEFT JOIN sys.objects   AS o ON p.object_id = o.object_id
    WHERE DB_NAME(b.database_id) = DB_NAME()
      AND ISNULL(o.name,'') = @ObjectName
    ORDER BY b.file_id, b.page_id;
END
ELSE
BEGIN
    PRINT '5) Skipping object sample (set @ObjectName to a valid object name to enable).';
END

/*=====================================================================
  6) Memory Clerks – who uses memory
=====================================================================*/
PRINT '6) Memory Clerks (top consumers)';
SELECT TOP(100)
    mc.name                         AS ClerkName,
    mc.type                         AS ClerkType,
    SUM(mc.virtual_memory_committed_kb) / 1024.0 AS MB_committed,
    SUM(mc.single_pages_kb + mc.multi_pages_kb) / 1024.0 AS MB_pages_kb_sum,
    SUM(mc.pages_kb) / 1024.0       AS MB_pages -- for versions where pages_kb is populated
FROM sys.dm_os_memory_clerks AS mc WITH (NOLOCK)
GROUP BY mc.name, mc.type
ORDER BY MB_pages DESC, MB_committed DESC;

/*=====================================================================
  7) Buffer/Memory perf counters (incl. PLE per NUMA node)
=====================================================================*/
PRINT '7) Perf counters (Buffer Manager / Memory Manager / PLE)';
;WITH c AS (
    SELECT
        object_name,
        counter_name,
        instance_name,
        cntr_value,
        cntr_type
    FROM sys.dm_os_performance_counters WITH (NOLOCK)
    WHERE object_name LIKE '%Buffer Manager%'
       OR object_name LIKE '%Memory Manager%'
       OR counter_name = 'Page life expectancy'
)
SELECT *
FROM c
ORDER BY object_name, counter_name, instance_name;

-- PLE per NUMA node (modern instances expose per-node instances)
PRINT '7a) Page Life Expectancy by NUMA node';
SELECT
    instance_name AS NUMA_Node,
    cntr_value    AS PageLifeExpectancy_seconds
FROM sys.dm_os_performance_counters WITH (NOLOCK)
WHERE counter_name = 'Page life expectancy'
ORDER BY
    CASE WHEN TRY_CONVERT(int, instance_name) IS NULL THEN 2147483647 ELSE TRY_CONVERT(int, instance_name) END;

/*=====================================================================
  8) Plan cache (not Buffer Pool, but useful to see memory pressure contributors)
=====================================================================*/
PRINT '8) Plan cache size by type';
SELECT TOP(50)
    cp.cacheobjtype,
    cp.objtype,
    COUNT(*) AS plan_count,
    SUM(cp.size_in_bytes) / 1024.0 / 1024.0 AS MB_cache
FROM sys.dm_exec_cached_plans AS cp WITH (NOLOCK)
GROUP BY cp.cacheobjtype, cp.objtype
ORDER BY MB_cache DESC;

/*=====================================================================
  9) Inspect a specific page with DBCC PAGE (manual step)
     - 1) Find file_id/page_id from section (5)
     - 2) Replace DB, file, page below and execute
       NOTE: DBCC PAGE output goes to the client when TRACEON(3604) is enabled.
             Use on non-production where possible.
=====================================================================*/
-- Example (commented out):
-- DBCC TRACEON(3604);
-- DBCC PAGE (N'YourDatabaseName', 1, 12345, 3); -- level 3 = detailed
-- DBCC TRACEOFF(3604);

/*=====================================================================
  10) Helpful: memory grants in execution (to correlate with memory pressure)
=====================================================================*/
PRINT '10) Active/Recent memory grants';
SELECT TOP (100)
    mg.request_time,
    mg.grant_time,
    mg.requested_memory_kb/1024.0 AS requested_MB,
    mg.granted_memory_kb/1024.0   AS granted_MB,
    mg.max_used_memory_kb/1024.0  AS max_used_MB,
    mg.is_next_fetch_resumable,
    DB_NAME(rs.database_id)       AS database_name,
    rs.status,
    rs.wait_type,
    rs.cpu_time,
    rs.total_elapsed_time,
    SUBSTRING(t.text, (rs.statement_start_offset/2) + 1,
                     CASE WHEN rs.statement_end_offset = -1
                          THEN (DATALENGTH(t.text) - rs.statement_start_offset)/2 + 1
                          ELSE (rs.statement_end_offset - rs.statement_start_offset)/2 + 1
                     END) AS statement_text
FROM sys.dm_exec_query_memory_grants AS mg WITH (NOLOCK)
JOIN sys.dm_exec_requests AS rs WITH (NOLOCK) ON mg.session_id = rs.session_id
CROSS APPLY sys.dm_exec_sql_text(rs.sql_handle) AS t
ORDER BY mg.grant_time DESC;

/*=====================================================================
  END
=====================================================================*/
PRINT 'BufferPool_Audit finished at ' + CONVERT(varchar(19), SYSDATETIME(), 120);
