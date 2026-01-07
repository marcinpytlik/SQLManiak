/* 02_PlanCache_Fallback.sql
   Fallback, gdy Query Store nie pomoże.
   To NIE jest precyzyjny „time window”, ale daje tropy: które warianty zapytań są najcięższe.
*/
DECLARE @Like nvarchar(200) = N'%Nazwatabeli%';

SELECT TOP (50)
    qs.last_execution_time,
    qs.execution_count,
    (qs.total_elapsed_time/1000.0) AS total_elapsed_ms,
    (qs.total_worker_time/1000.0)  AS total_cpu_ms,
    qs.total_logical_reads,
    qs.total_logical_writes,
    qs.total_physical_reads,
    qs.max_elapsed_time/1000.0 AS max_elapsed_ms,
    qs.max_worker_time/1000.0  AS max_cpu_ms,
    qs.max_logical_reads,
    qs.sql_handle,
    qs.plan_handle,
    LEFT(REPLACE(REPLACE(st.text, CHAR(10),' '), CHAR(13),' '), 4000) AS query_text_4k
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE st.text LIKE @Like
   OR st.text LIKE N'%Nazwatabeli%'  -- na wypadek literówki
ORDER BY qs.max_elapsed_time DESC, qs.total_elapsed_time DESC;

-- Plan dla konkretnego plan_handle (wklej z wyniku powyżej)
-- SELECT TRY_CONVERT(xml, qp.query_plan)
-- FROM sys.dm_exec_query_plan(0x...);
