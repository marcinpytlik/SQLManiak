USE tempdb;
GO
BEGIN TRAN;
DELETE TOP (1000) FROM dbo.DemoDeleteTruncate;
-- Zostaw transakcję otwartą jeśli chcesz przetestować ROLLBACK
COMMIT;
GO
