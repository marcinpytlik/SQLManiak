/* XE Template — InternalsWatch (ring_buffer)
   1) Uruchom najpierw xe/Find-Events.sql, by znaleźć dokładne nazwy eventów w Twojej wersji.
   2) Wstaw nazwy eventów w miejsce TODO_* i uruchom.
*/

IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = N'InternalsWatch')
    DROP EVENT SESSION [InternalsWatch] ON SERVER;
GO

CREATE EVENT SESSION [InternalsWatch] ON SERVER
ADD EVENT sqlserver.checkpoint_begin ACTION(sqlserver.session_id, sqlserver.sql_text) -- jeśli dostępne
,ADD EVENT sqlserver.checkpoint_end   ACTION(sqlserver.session_id)
-- TODO: poniższe wstaw tylko, jeśli występują w Twojej wersji:
-- ,ADD EVENT sqlserver.ghost_cleanup
-- ,ADD EVENT sqlserver.resource_monitor
-- ,ADD EVENT sqlserver.xtp_gc_cycle_begin
-- ,ADD EVENT sqlserver.xtp_gc_cycle_end
ADD TARGET package0.ring_buffer (SET max_memory = 4096)
WITH (STARTUP_STATE=OFF);
GO

ALTER EVENT SESSION [InternalsWatch] ON SERVER STATE = START;
GO

-- Podgląd ring_buffer
SELECT CAST(xet.target_data AS XML) AS ring_buffer_xml
FROM sys.dm_xe_sessions AS xes
JOIN sys.dm_xe_session_targets AS xet
  ON xes.address = xet.event_session_address
WHERE xes.name = N'InternalsWatch'
  AND xet.target_name = N'ring_buffer';
