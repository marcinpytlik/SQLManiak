-- Widok: Replication_Errors_Dashboard
-- Agreguje ostatnie błędy z dystrybutora + statusy agentów.
-- Zmien bazę 'distribution' jeśli inna.
USE distribution;
GO

IF OBJECT_ID('dbo.Replication_Errors_Dashboard') IS NOT NULL
    DROP VIEW dbo.Replication_Errors_Dashboard;
GO

CREATE VIEW dbo.Replication_Errors_Dashboard
AS
SELECT TOP (500)
    e.time              AS ErrorTime,
    e.error_code,
    e.xact_seqno,
    e.command_id,
    e.error_text,
    ISNULL(da.name, lra.name) AS AgentName,
    hist.RunStatusText,
    hist.LastComment
FROM dbo.MSrepl_errors e
OUTER APPLY (
    SELECT TOP(1)
        h.runstatus,
        CASE h.runstatus
            WHEN 1 THEN 'Start' WHEN 2 THEN 'Success' WHEN 3 THEN 'InProgress'
            WHEN 4 THEN 'Idle'  WHEN 5 THEN 'Retry'   WHEN 6 THEN 'Failed' END AS RunStatusText,
        h.comments AS LastComment,
        h.time
    FROM dbo.MSdistribution_history h
    WHERE h.error_id = e.id
    ORDER BY h.time DESC
) hist
LEFT JOIN dbo.MSdistribution_agents da ON da.id = (
    SELECT TOP(1) agent_id FROM dbo.MSdistribution_history WHERE error_id = e.id ORDER BY time DESC
)
LEFT JOIN dbo.MSlogreader_agents lra ON lra.id = (
    SELECT TOP(1) agent_id FROM dbo.MSlogreader_history WHERE error_id = e.id ORDER BY time DESC
)
ORDER BY e.time DESC;
GO

-- Użycie:
-- SELECT * FROM distribution.dbo.Replication_Errors_Dashboard ORDER BY ErrorTime DESC;
