/* Lab 03 — Aktywna transakcja blokuje truncation (dwie sesje) */

/**************  SESJA A  **************/
-- USE LogLab;
-- BEGIN TRAN;
-- UPDATE TOP (100000) dbo.BigT SET Pad = REPLICATE('Y',8000);
-- -- Nie rób COMMIT/ROLLBACK — zostaw transakcję otwartą

/**************  SESJA B  **************/
-- USE LogLab;
SELECT log_truncation_holdup_reason
FROM sys.dm_db_log_stats(DB_ID());   -- Oczekuj: ACTIVE_TRANSACTION

BACKUP LOG LogLab TO DISK = 'C:\Temp\LogLab_log2.trn' WITH COMPRESSION; -- wykona się, ale truncation minimalne
DBCC SHRINKFILE (LogLab_log, 64);    -- najczęściej bez efektu

/* Po zakończeniu transakcji w SESJI A (COMMIT/ROLLBACK): */
-- BACKUP LOG LogLab TO DISK = 'C:\Temp\LogLab_log3.trn' WITH COMPRESSION;
-- DBCC SHRINKFILE (LogLab_log, 64);
