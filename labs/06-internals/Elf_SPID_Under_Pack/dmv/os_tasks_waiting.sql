/* DMV: Wątki i czekania dla SPID < 50 */
SET NOCOUNT ON;

SELECT t.session_id,
       wt.wait_type,
       wt.resource_description,
       t.scheduler_id,
       t.task_state,
       wt.blocking_session_id
FROM sys.dm_os_tasks AS t
JOIN sys.dm_os_waiting_tasks AS wt
  ON t.task_address = wt.task_address
WHERE t.session_id < 50
ORDER BY t.session_id;
