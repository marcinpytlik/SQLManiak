USE DemoVersioning;
GO
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
GO
BEGIN TRAN;
SELECT COUNT(*) AS snapshot_visible_rows FROM dbo.T;
-- Trzymaj transakcję otwartą, żeby utrzymać wersję
-- COMMIT po obserwacji
