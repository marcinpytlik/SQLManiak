/* Workspace_Memory_Current_Grants.sql
   Szczegóły największych bieżących grantów.
*/
SET NOCOUNT ON;

SELECT TOP (50)
    mg.session_id,
    mg.requested_memory_kb/1024.0 AS RequestedMB,
    mg.granted_memory_kb/1024.0   AS GrantedMB,
    mg.max_used_memory_kb/1024.0  AS MaxUsedMB,
    mg.request_time,
    mg.grant_time,
    mg.is_small,
    mg.dop,
    st.text AS SQLText
FROM sys.dm_exec_query_memory_grants AS mg
CROSS APPLY sys.dm_exec_sql_text(mg.sql_handle) AS st
ORDER BY mg.requested_memory_kb DESC;
