
/* Tworzy bazę AuditDB (jeśli nie istnieje) i podstawowe ustawienia */
IF DB_ID(N'AuditDB') IS NULL
BEGIN
    DECLARE @sql nvarchar(max) = N'CREATE DATABASE AuditDB';
    EXEC (@sql);
END
GO

ALTER DATABASE AuditDB SET RECOVERY SIMPLE;
GO
