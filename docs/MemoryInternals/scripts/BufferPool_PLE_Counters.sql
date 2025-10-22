/* BufferPool_PLE_Counters.sql
   PLE per NUMA node (perf counter).
*/
SET NOCOUNT ON;

SELECT
    pc.object_name,
    pc.instance_name AS NumaNode,
    pc.cntr_value     AS PLE_Seconds
FROM sys.dm_os_performance_counters AS pc
WHERE pc.counter_name = 'Page life expectancy'
  AND pc.object_name LIKE '%Buffer Manager%'
ORDER BY pc.instance_name;
