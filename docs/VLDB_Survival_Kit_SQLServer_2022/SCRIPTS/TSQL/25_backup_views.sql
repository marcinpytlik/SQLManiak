/* 25_backup_views.sql
Widoki pomocnicze do inspekcji łańcucha backupów i rozmiarów.
*/
USE msdb;
GO
IF OBJECT_ID('dbo.v_BackupHistory','V') IS NOT NULL DROP VIEW dbo.v_BackupHistory;
GO
CREATE VIEW dbo.v_BackupHistory AS
SELECT
    b.database_name,
    b.backup_start_date,
    b.backup_finish_date,
    b.type AS backup_type, -- D=Database, I=Diff, L=Log
    b.backup_size/1024.0/1024.0/1024.0 AS backup_size_GB,
    mf.physical_device_name
FROM dbo.backupset b
JOIN dbo.backupmediafamily mf ON b.media_set_id = mf.media_set_id;

-- Rozmiary plików danych/logów
USE VLDB;
GO
IF OBJECT_ID('dbo.v_FileSizes','V') IS NOT NULL DROP VIEW dbo.v_FileSizes;
GO
CREATE VIEW dbo.v_FileSizes AS
SELECT
    fg.name AS filegroup_name,
    df.name AS file_name,
    df.type_desc,
    (df.size/128.0) AS size_MB,
    (df.max_size/128.0) AS max_size_MB,
    df.growth
FROM sys.database_files df
LEFT JOIN sys.filegroups fg ON df.data_space_id = fg.data_space_id;
