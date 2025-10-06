USE DemoVersioning;
GO
BEGIN TRAN;
DELETE TOP (10000) FROM dbo.T;
-- Nie commituj od razu – obserwuj czytelnika (RCSI/SNAPSHOT) w innych oknach
-- COMMIT/ROLLBACK po obserwacji
