-- KIM JESTEM (login vs. oryginalny login vs. user w bazie)
SELECT
  SUSER_SNAME()        AS login_name,        -- bieżący kontekst logowania (po EXECUTE AS może być inny)
  ORIGINAL_LOGIN()     AS original_login,    -- login, który utworzył sesję
  SYSTEM_USER          AS 'system_user',       -- alias do loginu
  SESSION_USER         AS db_user,           -- użytkownik w bieżącej bazie
  USER_NAME()          AS user_name,         -- to samo co wyżej (synonim)
  CURRENT_USER         AS 'current_user',
  USER_ID()            AS user_id,
  DB_NAME()            AS db_name,
  @@SPID               AS spid;
GO
USE master;
GO
SELECT HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') AS can_view_server;
SELECT TOP 10 session_id, status, command FROM sys.dm_exec_requests;
SELECT TOP 5 wait_type, waiting_tasks_count
FROM sys.dm_os_wait_stats ORDER BY wait_time_ms DESC;
GO
USE AdventureWorks2022;
GO
SELECT HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'VIEW DATABASE STATE') AS can_view_db;
SELECT TOP 10 * FROM sys.dm_db_log_space_usage;
SELECT TOP 10 * FROM sys.dm_db_index_usage_stats WHERE database_id = DB_ID();

