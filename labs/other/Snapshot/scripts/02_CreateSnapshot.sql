
-- 02_CreateSnapshot.sql
-- Tworzy snapshot i raportuje rozmiary.

:setvar DatabaseName SnapshotDemoDB
:setvar SnapshotName SnapshotDemoDB_SS
:setvar DataPath C:\SQL\SnapshotDemo

USE master;
GO

IF DB_ID('$(SnapshotName)') IS NOT NULL
BEGIN
    ALTER DATABASE [$(SnapshotName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$(SnapshotName)];
END
GO

DECLARE @db sysname = '$(DatabaseName)';
DECLARE @ss sysname = '$(SnapshotName)';
DECLARE @ssfile nvarchar(260) = '$(DataPath)\' + @ss + '.ss';

DECLARE @datafile sysname = (SELECT name FROM sys.master_files WHERE database_id = DB_ID(@db) AND type_desc='ROWS');
DECLARE @sql nvarchar(max) = N'CREATE DATABASE ['+@ss+'] ON
( NAME = N'''+@datafile+''', FILENAME = N'''+@ssfile+''' )
AS SNAPSHOT OF ['+@db+'];';
EXEC(@sql);

PRINT '>> Snapshot utworzony.';

SELECT DB_NAME(database_id) AS db, name, physical_name, size*8/1024.0 AS size_MB, type_desc
FROM sys.master_files
WHERE DB_NAME(database_id) IN ('$(DatabaseName)', '$(SnapshotName)')
ORDER BY db, type_desc, name;
