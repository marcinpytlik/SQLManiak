-- scripts/03_fix.sql
-- Strategia naprawy: shrink do małego rozmiaru i regrow w dużych blokach.

USE master;
GO

-- 1) Wykonaj backup logu, jeżeli recovery FULL i istnieją aktywne transakcje
-- BACKUP LOG VLF_Lab TO DISK = 'C:\SQLBackups\VLF_Lab_log.trn' WITH INIT;

-- 2) Skróć log do minimalnego rozmiaru
DBCC SHRINKFILE (N'VLF_Lab_log', 64); -- w MB

-- 3) Ustaw rozsądny rozmiar początkowy i growth (np. 4GB start, 512MB growth) — DOSTOSUJ DO ŚRODOWISKA
ALTER DATABASE VLF_Lab MODIFY FILE (NAME = N'VLF_Lab_log', SIZE = 4096MB, FILEGROWTH = 512MB);

-- 4) Zweryfikuj liczbę VLF po zmianach
USE VLF_Lab;
GO
SELECT COUNT(*) AS VLF_Count
FROM sys.dm_db_log_info(DB_ID());

SELECT file_id, vlf_size_mb, vlf_sequence_number, vlf_active
FROM sys.dm_db_log_info(DB_ID())
ORDER BY vlf_begin_offset;
