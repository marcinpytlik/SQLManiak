-- scripts/01_setup.sql
USE master;
IF DB_ID('CE_Lab') IS NOT NULL BEGIN ALTER DATABASE CE_Lab SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE CE_Lab; END;
GO
CREATE DATABASE CE_Lab;
-- Domyślnie current CE (zależnie od wersji). Podniesiemy do 160 jeśli 2022.
ALTER DATABASE CE_Lab SET COMPATIBILITY_LEVEL = 160;
GO

USE CE_Lab;
GO
-- Dane z korelacją i skew
CREATE TABLE dbo.CorrData
(
    Id INT IDENTITY(1,1) PRIMARY KEY,
    A INT NOT NULL,
    B INT NOT NULL,
    Pad CHAR(200) NOT NULL DEFAULT REPLICATE('C',200)
);
;WITH n AS (
    SELECT TOP (500000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT dbo.CorrData (A,B)
SELECT 
    CASE WHEN rn % 10 = 0 THEN rn % 1000 ELSE 1 END,          -- 90% A=1, reszta rozproszona
    CASE WHEN rn % 10 = 0 THEN rn % 1000 ELSE (CASE WHEN rn % 3 = 0 THEN 1 ELSE 2 END) END  -- korelacja
FROM n;

CREATE INDEX IX_Corr_A ON dbo.CorrData(A);
CREATE INDEX IX_Corr_B ON dbo.CorrData(B);
GO
