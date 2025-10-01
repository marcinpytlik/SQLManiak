-- scripts/02_workload_sniffing.sql
USE QS_Lab;
GO
SET NOCOUNT ON;
-- Dwa różne parametry → dwa różne plany
DECLARE @r INT;

-- „Rzadki” region (zachęca do seeków)
SET @r = 99;
SELECT COUNT(*) FROM dbo.SalesSkew WHERE Region = @r;

-- „Gęsty” region (zachęca do skanu/hash)
SET @r = 1;
SELECT COUNT(*) FROM dbo.SalesSkew WHERE Region = @r;
GO 50
