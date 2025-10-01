-- scripts/03_toggle_ce.sql
-- Test porównawczy: CE legacy vs current
USE master;
GO
-- Legacy
ALTER DATABASE CE_Lab SET COMPATIBILITY_LEVEL = 70;  -- legacy CE
GO
DBCC FREEPROCCACHE;
GO
USE CE_Lab;
GO
:r .\scripts\02_queries.sql

-- Current (np. 160)
USE master;
GO
ALTER DATABASE CE_Lab SET COMPATIBILITY_LEVEL = 160;
GO
DBCC FREEPROCCACHE;
GO
USE CE_Lab;
GO
:r .\scripts\02_queries.sql
