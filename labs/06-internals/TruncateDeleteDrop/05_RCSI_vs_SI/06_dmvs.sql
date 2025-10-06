USE DemoVersioning;
GO
-- Ile zajmuje version store (per baza)?
SELECT * FROM sys.dm_tran_version_store_space_usage;

-- Aktywne transakcje snapshotowe
SELECT * FROM sys.dm_tran_active_snapshot_database_transactions;

-- Podstawowe waity (przykład: sprawdź czy nie ma WRITELOG/LCK_M_*)
SELECT TOP (50) * FROM sys.dm_os_waiting_tasks ORDER BY wait_duration_ms DESC;
