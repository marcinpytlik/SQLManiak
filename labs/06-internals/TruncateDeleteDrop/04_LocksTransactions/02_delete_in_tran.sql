USE tempdb;
GO
BEGIN TRAN;
DELETE TOP (5000) FROM dbo.DemoLocks;
-- Spójrz na blokady w drugim oknie (04_locks_query.sql)
-- COMMIT lub ROLLBACK po obserwacji
