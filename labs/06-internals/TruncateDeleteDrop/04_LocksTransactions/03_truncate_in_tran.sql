USE tempdb;
GO
BEGIN TRAN;
TRUNCATE TABLE dbo.DemoLocks;
-- Spójrz na blokady w drugim oknie (04_locks_query.sql)
-- COMMIT lub ROLLBACK po obserwacji
