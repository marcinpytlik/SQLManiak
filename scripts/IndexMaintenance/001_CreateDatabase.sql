/* SQLManiak Index Maintenance — centralna baza. SQL Server 2022+. */
USE [master];
GO
IF DB_ID(N'SQLManiakIndexMaintenance') IS NULL
    CREATE DATABASE [SQLManiakIndexMaintenance];
GO
/* Sprawdź model odzyskiwania, lokalizację plików i politykę backupów.
   Istniejącej konfiguracji bazy skrypt nie nadpisuje. */
SELECT name, state_desc, recovery_model_desc, compatibility_level
FROM sys.databases WHERE name = N'SQLManiakIndexMaintenance';
GO
