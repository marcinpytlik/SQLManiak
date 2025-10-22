/* Target_vs_Total_Server_Memory.sql
   Zestawienie Target vs Total Server Memory + stan procesu.
*/
SET NOCOUNT ON;

SELECT
    MAX(CASE WHEN counter_name = 'Target Server Memory (KB)' THEN cntr_value END) / 1024.0 AS TargetMB,
    MAX(CASE WHEN counter_name = 'Total Server Memory (KB)'  THEN cntr_value END) / 1024.0 AS TotalMB
FROM sys.dm_os_performance_counters
WHERE object_name LIKE '%Memory Manager%'
  AND counter_name IN ('Target Server Memory (KB)', 'Total Server Memory (KB)');

SELECT
    physical_memory_kb/1024.0 AS OS_PhysicalMB,
    large_page_allocations_kb/1024.0 AS LargePagesMB,
    memory_utilization_percentage AS SqlProcessMemoryUtilizationPct
FROM sys.dm_os_process_memory;
