/* Waits_Memory_Pressure.sql
   Profil pamięciowych waitów.
*/
SET NOCOUNT ON;

SELECT TOP (20)
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms
FROM sys.dm_os_wait_stats
WHERE wait_type IN (
    'RESOURCE_SEMAPHORE','RESOURCE_SEMAPHORE_QUERY_COMPILE',
    'MEMORY_GRANT_UPDATE','CMEMTHREAD',
    'PAGEIOLATCH_SH','PAGEIOLATCH_EX','PAGEIOLATCH_UP'
)
ORDER BY wait_time_ms DESC;
