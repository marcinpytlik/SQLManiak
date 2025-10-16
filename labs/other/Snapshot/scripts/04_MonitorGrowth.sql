
-- 04_MonitorGrowth.sql
-- Podgląd rozmiarów snapshotu i tempdb/Version Store.

:setvar DatabaseName SnapshotDemoDB
:setvar SnapshotName SnapshotDemoDB_SS

-- 1) Rozmiary plików bazy i snapshotu
SELECT DB_NAME(mf.database_id) AS db, mf.name, mf.type_desc, mf.physical_name,
       (mf.size*8.0)/1024 AS size_MB
FROM sys.master_files AS mf
WHERE DB_NAME(mf.database_id) IN ('$(DatabaseName)', '$(SnapshotName)')
ORDER BY db, type_desc, name;

-- 2) Version Store per baza (tempdb)
SELECT DB_NAME(database_id) AS db,
       total_version_store_reserved_page_count/128.0 AS version_store_MB
FROM sys.dm_tran_version_store_space_usage
ORDER BY version_store_MB DESC;

-- 3) tempdb zużycie (uruchom w kontekście tempdb!)
USE tempdb;
SELECT (user_object_reserved_page_count +
        internal_object_reserved_page_count +
        version_store_reserved_page_count +
        mixed_extent_page_count)/128.0 AS tempdb_total_MB,
       version_store_reserved_page_count/128.0 AS version_store_MB
FROM sys.dm_db_file_space_usage;

-- wróć
USE master;
-- 4) Aktywne snapshot-transakcje
SELECT transaction_id, elapsed_time_seconds, database_id, DB_NAME(database_id) AS db_name
FROM sys.dm_tran_active_snapshot_database_transactions
ORDER BY elapsed_time_seconds DESC;
