/* 15_stats_vldb.sql
Zarządzanie statystykami w VLDB.
*/
USE VLDB;
GO
-- Incremental statistics dla indeksów partycjonowanych
ALTER DATABASE SCOPED CONFIGURATION SET INCREMENTAL_STATS = ON;
GO

-- Przykładowa aktualizacja statystyk z próbkowaniem
UPDATE STATISTICS dbo.FactSale WITH FULLSCAN, PERSIST_SAMPLE_PERCENT = ON; -- uwaga na koszty!
-- Alternatywnie: percent sample
-- UPDATE STATISTICS dbo.FactSale WITH SAMPLE 3 PERCENT;
GO

-- Filtered stats dla rozkładu skośnego (np. wysokie kwoty)
IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE name = N'STF_Amount_High')
    CREATE STATISTICS STF_Amount_High ON dbo.FactSale(Amount) WHERE Amount > 10000;
GO
