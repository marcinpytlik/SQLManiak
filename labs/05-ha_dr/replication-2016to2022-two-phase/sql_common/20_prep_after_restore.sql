/*
  Post-restore higiena (na 130): CHECKDB + STATs + Query Store
  Uruchom po przywróceniu bazy na C/D, zanim podniesiesz compatibility level.
*/
USE [master];
DECLARE @Db sysname = N'TwojaBaza'; -- PODMIEŃ

-- 1) CHECKDB (opcjonalnie usuń jeśli nie masz okna)
DBCC CHECKDB(@Db) WITH NO_INFOMSGS;

-- 2) Statystyki – dla krytycznych tabel rozważ FULLSCAN; poniżej przykład całościowy
EXECUTE sys.sp_MSforeachtable @command1 = N'UPDATE STATISTICS ? WITH FULLSCAN';

-- 3) Query Store ON + RW (jeśli nie było)
DECLARE @sql nvarchar(max) = N'
ALTER DATABASE [' + @Db + N'] SET QUERY_STORE = ON;
ALTER DATABASE [' + @Db + N'] SET QUERY_STORE (OPERATION_MODE = READ_WRITE);';
EXEC(@sql);

-- 4) Automatyczna korekcja planów (FLGP)
SET @sql = N'ALTER DATABASE [' + @Db + N'] SET AUTOMATIC_TUNING ( FORCE_LAST_GOOD_PLAN = ON );';
EXEC(@sql);
PRINT 'Post-restore prep done for ' + @Db;
