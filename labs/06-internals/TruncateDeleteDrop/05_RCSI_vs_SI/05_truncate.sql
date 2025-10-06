USE DemoVersioning;
GO
-- Zwróć uwagę: TRUNCATE nie generuje wersji – to deallocacja stron i Sch-M lock
TRUNCATE TABLE dbo.T;
