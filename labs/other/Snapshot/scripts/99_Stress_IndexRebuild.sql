
-- 99_Stress_IndexRebuild.sql
-- Opcjonalny stres: online rebuild indeksu (Enterprise) mocno zwiększy snapshot.

:setvar DatabaseName SnapshotDemoDB

USE [$(DatabaseName)];
GO

-- Dodajemy indeks nieklastrowy, potem rebuild online
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Sales_OrderDate')
    CREATE INDEX IX_Sales_OrderDate ON dbo.Sales(OrderDate);

ALTER INDEX IX_Sales_OrderDate ON dbo.Sales REBUILD WITH (ONLINE = ON);
PRINT '>> Rebuild online wykonany.';
