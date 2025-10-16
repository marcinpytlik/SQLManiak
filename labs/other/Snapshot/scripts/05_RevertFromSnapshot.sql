
-- 05_RevertFromSnapshot.sql
-- Przywracanie bazy do stanu ze snapshotu.

:setvar DatabaseName SnapshotDemoDB
:setvar SnapshotName SnapshotDemoDB_SS

USE master;
IF DB_ID('$(SnapshotName)') IS NULL
BEGIN
    RAISERROR('Snapshot $(SnapshotName) nie istnieje.', 16, 1);
    RETURN;
END

ALTER DATABASE [$(DatabaseName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
RESTORE DATABASE [$(DatabaseName)] FROM DATABASE_SNAPSHOT = '$(SnapshotName)';
ALTER DATABASE [$(DatabaseName)] SET MULTI_USER;
PRINT '>> Przywrócono bazę ze snapshotu.';
