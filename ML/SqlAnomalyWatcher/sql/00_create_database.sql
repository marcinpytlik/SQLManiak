USE master;
GO

IF DB_ID('SqlAnomalyWatcherDb') IS NULL
BEGIN
    CREATE DATABASE SqlAnomalyWatcherDb;
END
GO