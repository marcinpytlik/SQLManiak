/*
  Szablon do hurtowego podnoszenia kilku baz do 160 na serwerze.
  Uzupełnij listę @dbs, uruchom na C lub D.
*/
DECLARE @dbs TABLE(name sysname);
INSERT INTO @dbs(name) VALUES (N'TwojaBaza');  -- dodaj kolejne bazy

DECLARE @name sysname;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM @dbs;
OPEN cur; FETCH NEXT FROM cur INTO @name;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT '== ' + @name + ' ==';
    EXEC(N'ALTER DATABASE [' + @name + N'] SET QUERY_STORE = ON;');
    EXEC(N'ALTER DATABASE [' + @name + N'] SET QUERY_STORE (OPERATION_MODE = READ_WRITE);');
    EXEC(N'ALTER DATABASE [' + @name + N'] SET AUTOMATIC_TUNING ( FORCE_LAST_GOOD_PLAN = ON );');
    EXEC(N'ALTER DATABASE [' + @name + N'] SET COMPATIBILITY_LEVEL = 160;');
    EXEC(N'USE [' + @name + N']; ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;');
    FETCH NEXT FROM cur INTO @name;
END
CLOSE cur; DEALLOCATE cur;
