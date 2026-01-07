/* 04_XE_LongRunning_and_Blocking.sql
   Extended Events: łapie długie RPC/batche + blocking/deadlock.
   Dzięki temu przy następnym incydencie masz „twardy dowód” bez ręcznego polowania.

   Ustaw ścieżkę pod siebie (dysk lokalny, nie sieciowy).
*/
DECLARE @xel_path nvarchar(260) = N'C:\XEvents\RequestPerf.xel';

IF NOT EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = N'RequestPerf')
BEGIN
    EXEC('
    CREATE EVENT SESSION [RequestProcessorPerf] ON SERVER
    ADD EVENT sqlserver.rpc_completed
    (
        ACTION
        (
            sqlserver.client_app_name,
            sqlserver.client_hostname,
            sqlserver.database_name,
            sqlserver.session_id,
            sqlserver.sql_text,
            sqlserver.username,
            sqlserver.query_hash,
            sqlserver.query_plan_hash
        )
        WHERE (duration > 1000000) -- > 1s (microseconds)
    ),
    ADD EVENT sqlserver.sql_batch_completed
    (
        ACTION
        (
            sqlserver.client_app_name,
            sqlserver.client_hostname,
            sqlserver.database_name,
            sqlserver.session_id,
            sqlserver.sql_text,
            sqlserver.username,
            sqlserver.query_hash,
            sqlserver.query_plan_hash
        )
        WHERE (duration > 1000000) -- > 1s
    ),
    ADD EVENT sqlserver.blocked_process_report
    (
        ACTION
        (
            sqlserver.client_app_name,
            sqlserver.client_hostname,
            sqlserver.database_name,
            sqlserver.session_id,
            sqlserver.sql_text,
            sqlserver.username
        )
    ),
    ADD EVENT sqlserver.xml_deadlock_report
    (
        ACTION
        (
            sqlserver.client_app_name,
            sqlserver.client_hostname,
            sqlserver.database_name,
            sqlserver.session_id,
            sqlserver.sql_text,
            sqlserver.username
        )
    )
    ADD TARGET package0.event_file(SET filename = "' + @xel_path + '", max_file_size=(100), max_rollover_files=(10))
    WITH (MAX_MEMORY=64MB, EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY=5 SECONDS, TRACK_CAUSALITY=ON);
    ');
END;

-- Start
ALTER EVENT SESSION [RequestProcessorPerf] ON SERVER STATE = START;

-- Czy działa?
SELECT name, startup_state, is_running
FROM sys.server_event_sessions s
JOIN sys.dm_xe_sessions x ON s.name = x.name
WHERE s.name = N'RequestProcessorPerf';

-- Stop (po incydencie)
-- ALTER EVENT SESSION [RequestProcessorPerf] ON SERVER STATE = STOP;

-- Odczyt (podmień ścieżkę)
-- SELECT TOP (200)
--     DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), SYSDATETIME()), CAST(event_data AS xml).value('(event/@timestamp)[1]', 'datetime2')) AS event_time_local,
--     CAST(event_data AS xml).value('(event/action[@name="database_name"]/value)[1]','sysname') AS database_name,
--     CAST(event_data AS xml).value('(event/data[@name="duration"]/value)[1]','bigint')/1000.0 AS duration_ms,
--     CAST(event_data AS xml).value('(event/action[@name="client_app_name"]/value)[1]','nvarchar(256)') AS client_app,
--     CAST(event_data AS xml).value('(event/action[@name="client_hostname"]/value)[1]','nvarchar(256)') AS client_host,
--     CAST(event_data AS xml).value('(event/action[@name="username"]/value)[1]','nvarchar(256)') AS username,
--     CAST(event_data AS xml).value('(event/action[@name="session_id"]/value)[1]','int') AS session_id,
--     CAST(event_data AS xml).value('(event/action[@name="query_hash"]/value)[1]','varbinary(8)') AS query_hash,
--     CAST(event_data AS xml).value('(event/action[@name="query_plan_hash"]/value)[1]','varbinary(8)') AS query_plan_hash,
--     LEFT(CAST(event_data AS xml).value('(event/action[@name="sql_text"]/value)[1]','nvarchar(max)'), 4000) AS sql_text_4k
-- FROM sys.fn_xe_file_target_read_file(@xel_path, NULL, NULL, NULL);
