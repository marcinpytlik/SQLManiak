/* Memory_Clerks_Overview.sql
   Kto zużywa pamięć? Grupowanie po typie clerk'a.
*/
SET NOCOUNT ON;

SELECT
    type AS MemoryClerkType,
    SUM(pages_kb) / 1024.0 AS TotalMB,
    SUM(virtual_memory_committed_kb) / 1024.0 AS VMCommittedMB,
    SUM(awe_allocated_kb) / 1024.0 AS AWEMB
FROM sys.dm_os_memory_clerks
GROUP BY type
ORDER BY TotalMB DESC;
