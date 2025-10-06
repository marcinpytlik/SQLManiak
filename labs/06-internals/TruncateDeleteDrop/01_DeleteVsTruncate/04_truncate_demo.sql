USE tempdb;
GO
-- Sprawdź IDENTITY przed
SELECT IDENT_CURRENT('dbo.DemoDeleteTruncate') AS IdentityBefore;
TRUNCATE TABLE dbo.DemoDeleteTruncate;
-- Po TRUNCATE IDENTITY wraca do seed
SELECT IDENT_CURRENT('dbo.DemoDeleteTruncate') AS IdentityAfter;
GO
