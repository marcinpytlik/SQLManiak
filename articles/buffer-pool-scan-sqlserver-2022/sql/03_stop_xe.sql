/* Stop collection. Does not delete XEL files or the XE definition. */
IF EXISTS (SELECT 1 FROM sys.dm_xe_sessions WHERE name = N'BPS_Research_E0')
    ALTER EVENT SESSION [BPS_Research_E0] ON SERVER STATE = STOP;
GO
SELECT name, create_time
FROM sys.dm_xe_sessions WHERE name = N'BPS_Research_E0';
GO
