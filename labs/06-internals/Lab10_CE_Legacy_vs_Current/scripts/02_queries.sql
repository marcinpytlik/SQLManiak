-- scripts/02_queries.sql
USE CE_Lab;
GO
-- Dwa zapytania: niezależne predykaty vs skorelowane
SET STATISTICS IO, TIME ON;

-- Q1: A=1 AND B=1 (skew + korelacja)
SELECT COUNT(*) FROM dbo.CorrData WHERE A = 1 AND B = 1;

-- Q2: A=500 AND B=500 (rzadki kubełek)
SELECT COUNT(*) FROM dbo.CorrData WHERE A = 500 AND B = 500;

SET STATISTICS IO, TIME OFF;
