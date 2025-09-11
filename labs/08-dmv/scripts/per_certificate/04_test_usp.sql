use AdventureWorks2022;

GO
--exec dba.usp_exec_requests
-- powinien być błąd uruchom 05b_wrapper_dba.usp_waits.sql
--exec dba.usp_waits
exec dba.usp_plan_cache
--SELECT * from sys.dm_database_backups
