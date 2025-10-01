-- scripts/04_pvs_stats.sql
-- Statystyki PVS i sanity-check
SELECT DB_NAME(database_id) AS db, * 
FROM sys.dm_tran_persistent_version_store_stats
WHERE database_id IN (DB_ID('ADR_On_DB'), DB_ID('ADR_Off_DB'));

-- Ile wierszy zostało w tabelach (powinno być tyle co na starcie, jeśli rollback zadziałał)
SELECT 'ADR_On_DB' AS db, COUNT(*) AS rows_cnt FROM ADR_On_DB.dbo.T
UNION ALL
SELECT 'ADR_Off_DB', COUNT(*) FROM ADR_Off_DB.dbo.T;
