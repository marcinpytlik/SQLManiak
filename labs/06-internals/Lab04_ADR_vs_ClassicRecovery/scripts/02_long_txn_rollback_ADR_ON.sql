-- scripts/02_long_txn_rollback_ADR_ON.sql
USE ADR_On_DB;
GO
SET NOCOUNT ON;
DECLARE @tStart DATETIME2(3) = SYSUTCDATETIME();

BEGIN TRAN;
    DELETE TOP (200000) FROM dbo.T; -- długa operacja
    WAITFOR DELAY '00:00:02';       -- chwila, by zapisać wersje
ROLLBACK;                           -- klucz: rollback

DECLARE @tEnd DATETIME2(3) = SYSUTCDATETIME();
SELECT DATEDIFF(ms, @tStart, @tEnd) AS rollback_ms, 'ADR_ON' AS db;
GO
