/*
  Podniesienie COMPATIBILITY_LEVEL do 160 (SQL Server 2022) z pasami bezpieczeństwa.
  Zalecana kolejność: najpierw Subscriber (D), potem Publisher (C), na końcu distribution.
*/
USE [master];
DECLARE @Db sysname = N'TwojaBaza'; -- PODMIEŃ

PRINT '== Stan przed zmianą ==';
SELECT name, compatibility_level FROM sys.databases WHERE name = @Db;

-- Poduszki bezpieczeństwa (przed flipem)
EXEC(N'ALTER DATABASE [' + @Db + N'] SET QUERY_STORE = ON;');
EXEC(N'ALTER DATABASE [' + @Db + N'] SET QUERY_STORE (OPERATION_MODE = READ_WRITE);');
EXEC(N'ALTER DATABASE [' + @Db + N'] SET AUTOMATIC_TUNING ( FORCE_LAST_GOOD_PLAN = ON );');

-- Flip na 160
EXEC(N'ALTER DATABASE [' + @Db + N'] SET COMPATIBILITY_LEVEL = 160;');

-- Wyczyść cache planów dla TEJ bazy (żeby nowe plany powstały już na 160)
EXEC(N'ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;');

PRINT '== Stan po zmianie ==';
SELECT name, compatibility_level FROM sys.databases WHERE name = @Db;
