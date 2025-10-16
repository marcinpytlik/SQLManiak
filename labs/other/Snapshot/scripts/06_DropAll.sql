
-- 06_DropAll.sql
-- Sprzątanie: usuń snapshot i bazę.

:setvar DatabaseName SnapshotDemoDB
:setvar SnapshotName SnapshotDemoDB_SS

USE master;
IF DB_ID('$(SnapshotName)') IS NOT NULL
BEGIN
    ALTER DATABASE [$(SnapshotName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$(SnapshotName)];
END

IF DB_ID('$(DatabaseName)') IS NOT NULL
BEGIN
    ALTER DATABASE [$(DatabaseName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$(DatabaseName)];
END
PRINT '>> Usunięto bazę i snapshot.';
