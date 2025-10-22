/* Memory_Grants_Status.sql
   Granty pamięci dla wykonania planów + oczekujące.
*/
SET NOCOUNT ON;

SELECT
    GETDATE() AS CollectedAt,
    (SELECT COUNT(*) FROM sys.dm_exec_query_memory_grants WHERE grant_time IS NULL) AS PendingGrants,
    (SELECT COUNT(*) FROM sys.dm_exec_query_memory_grants WHERE grant_time IS NOT NULL) AS ActiveGrants;

SELECT TOP (50)
    mg.session_id,
    mg.requested_memory_kb/1024.0 AS RequestedMB,
    mg.granted_memory_kb/1024.0   AS GrantedMB,
    mg.max_used_memory_kb/1024.0  AS MaxUsedMB,
    mg.dop,
    mg.is_small, 
    mg.wait_time_ms,
    mg.queue_id,
    DB_NAME(st.dbid) AS DatabaseName,
    st.text AS SQLText
FROM sys.dm_exec_query_memory_grants AS mg
CROSS APPLY sys.dm_exec_sql_text(mg.sql_handle) AS st
ORDER BY mg.requested_memory_kb DESC;
