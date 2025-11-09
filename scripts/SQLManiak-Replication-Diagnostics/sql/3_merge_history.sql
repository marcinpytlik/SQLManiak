-- 3) Historia Merge Agent (jeśli używasz merge)
SET NOCOUNT ON;
SELECT TOP (200)
    h.start_time,
    a.name AS AgentName,
    CASE h.runstatus WHEN 1 THEN 'Start' WHEN 2 THEN 'Success' WHEN 3 THEN 'InProgress'
                     WHEN 4 THEN 'Idle'  WHEN 5 THEN 'Retry'   WHEN 6 THEN 'Failed' END AS RunStatus,
    h.comments,
    e.error_code,
    e.error_text
FROM distribution.dbo.MSmerge_history h
JOIN distribution.dbo.MSmerge_agents a ON a.id = h.agent_id
LEFT JOIN distribution.dbo.MSrepl_errors e ON e.id = h.error_id
ORDER BY h.start_time DESC;
