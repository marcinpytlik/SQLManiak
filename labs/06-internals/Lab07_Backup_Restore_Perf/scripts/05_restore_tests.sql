-- scripts/05_restore_tests.sql
-- Odtwarzanie do nowej bazy, czas trwania i integralność.
-- EDYTUJ ŚCIEŻKI I NAZWY PLIKÓW wg tego co zrobiono w krokach 2–4

USE master;
IF DB_ID('BkpLab_RestoreTest') IS NOT NULL BEGIN ALTER DATABASE BkpLab_RestoreTest SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE BkpLab_RestoreTest; END;
GO

-- Restore FULL striped
RESTORE DATABASE BkpLab_RestoreTest FROM 
DISK = N'C:\SQLBackups\BkpLab_full_s1.bak',
DISK = N'C:\SQLBackups\BkpLab_full_s2.bak',
DISK = N'C:\SQLBackups\BkpLab_full_s3.bak',
DISK = N'C:\SQLBackups\BkpLab_full_s4.bak'
WITH MOVE 'BkpLab' TO 'C:\SQLData\BkpLab_RestoreTest.mdf',
     MOVE 'BkpLab_log' TO 'C:\SQLData\BkpLab_RestoreTest.ldf',
     REPLACE, STATS=5;

-- Restore DIFF
RESTORE DATABASE BkpLab_RestoreTest FROM DISK = N'C:\SQLBackups\BkpLab_diff_01.bak' WITH STATS=5, REPLACE;

-- Restore LOG
RESTORE LOG BkpLab_RestoreTest FROM DISK = N'C:\SQLBackups\BkpLab_log_01.trn' WITH STATS=5, RECOVERY;

-- Weryfikacja
DBCC CHECKDB ('BkpLab_RestoreTest') WITH NO_INFOMSGS;
