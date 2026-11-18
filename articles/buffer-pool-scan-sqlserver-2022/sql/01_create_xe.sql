/*
 Buffer Pool Scan Research Lab — E0 telemetry (SQL Server 2022 CU27)
 Laboratory only. Run as sysadmin.
 Writes up to 4 * 20 MB event_file files under /var/opt/mssql/log.
 Re-running resets the lab XE session (not the prior XEL files).
*/
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_event_sessions
           WHERE name = N'BPS_Research_E0')
BEGIN
    ALTER EVENT SESSION [BPS_Research_E0] ON SERVER STATE = STOP;
    DROP EVENT SESSION [BPS_Research_E0] ON SERVER;
END;
GO

CREATE EVENT SESSION [BPS_Research_E0] ON SERVER
ADD EVENT sqlserver.buffer_pool_scan_start,
ADD EVENT sqlserver.buffer_pool_scan_complete,
ADD EVENT sqlserver.buffer_pool_scan_task_start,
ADD EVENT sqlserver.buffer_pool_scan_task_complete,
ADD EVENT sqlserver.buffer_pool_scan_task_error,
ADD EVENT sqlserver.buffer_pool_scan_stats
ADD TARGET package0.event_file
(
    SET filename = N'/var/opt/mssql/log/bps_research_e0.xel',
        max_file_size = (20),
        max_rollover_files = (4)
)
WITH
(
    MAX_MEMORY = 4096 KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 5 SECONDS,
    TRACK_CAUSALITY = OFF,
    STARTUP_STATE = OFF
);
GO
ALTER EVENT SESSION [BPS_Research_E0] ON SERVER STATE = START;
GO

SELECT s.name, x.name AS target_name, s.startup_state
FROM sys.server_event_sessions AS s
LEFT JOIN sys.server_event_session_targets AS x ON x.event_session_id = s.event_session_id
WHERE s.name = N'BPS_Research_E0';

SELECT name, create_time
FROM sys.dm_xe_sessions
WHERE name = N'BPS_Research_E0';
GO
