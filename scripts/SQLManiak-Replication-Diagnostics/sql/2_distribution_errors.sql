-- 2) Błędy z MSrepl_errors + historia dystrybucji
-- Zmień nazwę bazy dystrybucyjnej jeśli inna niż 'distribution'.
SET NOCOUNT ON;

-- a) Surowe błędy
SELECT TOP (200)
    e.id, e.time, e.error_code, e.xact_seqno, e.command_id, e.error_text
FROM distribution.dbo.MSrepl_errors e
ORDER BY e.time DESC;

-- b) Historia Distribution Agent z błędami
SELECT TOP (200)
    h.time,
    a.name       AS AgentName,
    CASE h.runstatus
         WHEN 1 THEN 'Start' WHEN 2 THEN 'Success' WHEN 3 THEN 'InProgress'
         WHEN 4 THEN 'Idle'  WHEN 5 THEN 'Retry'   WHEN 6 THEN 'Failed' END AS RunStatus,
    h.comments,
    e.error_code,
    e.error_text
FROM distribution.dbo.MSdistribution_history h
JOIN distribution.dbo.MSdistribution_agents a ON a.id = h.agent_id
LEFT JOIN distribution.dbo.MSrepl_errors e ON e.id = h.error_id
ORDER BY h.time DESC;

-- c) Historia Log Reader Agent z błędami
SELECT TOP (200)
    h.time,
    a.name AS AgentName,
    CASE h.runstatus WHEN 1 THEN 'Start' WHEN 2 THEN 'Success' WHEN 3 THEN 'InProgress'
                     WHEN 4 THEN 'Idle'  WHEN 5 THEN 'Retry'   WHEN 6 THEN 'Failed' END AS RunStatus,
    h.comments,
    e.error_code,
    e.error_text
FROM distribution.dbo.MSlogreader_history h
JOIN distribution.dbo.MSlogreader_agents a ON a.id = h.agent_id
LEFT JOIN distribution.dbo.MSrepl_errors e    ON e.id = h.error_id
ORDER BY h.time DESC;
