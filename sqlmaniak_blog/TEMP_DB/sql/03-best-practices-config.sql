
-- 03-best-practices-config.sql
-- SZABLON: Konfiguracja TempDB wg dobrych praktyk.
-- Edytuj parametry: target liczby plikow, rozmiar, autogrowth (MB).
-- Uruchom poza godzinami szczytu. Wymaga ALTER DATABASE tempdb ...

USE master;
GO

DECLARE @TargetFiles INT = 8;      -- docelowa liczba plikow danych tempdb
DECLARE @SizeMB      INT = 4096;   -- rozmiar kazdego pliku
DECLARE @GrowthMB    INT = 512;    -- autogrowth kazdego pliku

-- 1) Upewnij sie, ze istnieja pliki o numerach 1..@TargetFiles (file_id 1 to tempdev)
--    Dla brakujacych wygeneruj ALTER DATABASE ADD FILE.

DECLARE @CurrentFiles INT = (SELECT COUNT(*) FROM sys.master_files WHERE database_id = DB_ID('tempdb') AND type_desc = 'ROWS');
DECLARE @i INT = @CurrentFiles + 1;

WHILE @i <= @TargetFiles
BEGIN
    DECLARE @name sysname = CONCAT('tempdev', @i);
    DECLARE @path nvarchar(260) = (SELECT TOP 1 LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name))) FROM sys.master_files WHERE database_id = DB_ID('tempdb') AND file_id = 1);
    DECLARE @sql nvarchar(max) = N'ALTER DATABASE tempdb ADD FILE (NAME = ' + QUOTENAME(@name,'''') + N', FILENAME = ' + QUOTENAME(@path + '\' + @name + '.ndf','''') + N', SIZE = ' + CAST(@SizeMB AS nvarchar(10)) + N'MB, FILEGROWTH = ' + CAST(@GrowthMB AS nvarchar(10)) + N'MB);';
    PRINT @sql;
    EXEC(@sql);
    SET @i += 1;
END

-- 2) Wyrownaj rozmiary i autogrowth wszystkich plikow danych tempdb
DECLARE @sql2 nvarchar(max) = N'';
SELECT @sql2 = @sql2 + N'ALTER DATABASE tempdb MODIFY FILE (NAME = ' + QUOTENAME(name,'''') +
               N', SIZE = ' + CAST(@SizeMB AS nvarchar(10)) + N'MB, FILEGROWTH = ' + CAST(@GrowthMB AS nvarchar(10)) + N'MB);' + CHAR(13)+CHAR(10)
FROM sys.master_files
WHERE database_id = DB_ID('tempdb') AND type_desc = 'ROWS';
PRINT @sql2;
EXEC(@sql2);

PRINT 'Konfiguracja zaktualizowana. Pamietaj: restart instancji moze byc wymagany aby pliki zostaly pre-allocated.';
