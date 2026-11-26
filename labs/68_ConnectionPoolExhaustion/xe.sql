-- Optional lab-only session; run before experiment in SSMS.
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = N'Lab68')
    DROP EVENT SESSION Lab68 ON SERVER;
CREATE EVENT SESSION Lab68 ON SERVER
ADD EVENT sqlserver.login(WHERE ([sqlserver].[client_app_name]=N'SQLManiak.Lab68')),
ADD EVENT sqlserver.logout(WHERE ([sqlserver].[client_app_name]=N'SQLManiak.Lab68')),
ADD EVENT sqlserver.rpc_completed(ACTION(sqlserver.session_id,sqlserver.client_app_name) WHERE ([sqlserver].[client_app_name]=N'SQLManiak.Lab68')),
ADD EVENT sqlserver.sql_batch_completed(ACTION(sqlserver.session_id,sqlserver.client_app_name) WHERE ([sqlserver].[client_app_name]=N'SQLManiak.Lab68'))
ADD TARGET package0.ring_buffer;
ALTER EVENT SESSION Lab68 ON SERVER STATE=START;
-- In a separate query while running:
-- SELECT CAST(t.target_data AS xml) FROM sys.dm_xe_session_targets t JOIN sys.dm_xe_sessions s ON s.address=t.event_session_address WHERE s.name=N'Lab68';
-- Cleanup: DROP EVENT SESSION Lab68 ON SERVER;
