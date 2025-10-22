/* LazyWriter_Checkpoint_Stats.sql
   Ruch w tle: Lazy Writes/sec oraz Checkpoint Pages/sec.
*/
SET NOCOUNT ON;

SELECT 'Lazy Writes/sec' AS Counter, cntr_value
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Lazy Writes/sec' AND object_name LIKE '%Buffer Manager%'

UNION ALL

SELECT 'Checkpoint Pages/sec', cntr_value
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Checkpoint Pages/sec' AND object_name LIKE '%Buffer Manager%';
