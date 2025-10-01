-- scripts/04_fix.sql
-- Mitigacje: dodanie plików tempdb i wyrównanie rozmiarów.
-- ZAPLANUJ restart usługi po zmianach tempdb.

USE master;
GO

-- Rekomendacja: liczba plików = min(logical CPU, 8). Dla większych CPU dodawaj stopniowo i testuj.
-- Przykład: dodaj 3 dodatkowe pliki po 512MB (dostosuj ścieżki!).

-- !!! ZMIEŃ ŚCIEŻKI PONIŻEJ !!!
/*
ALTER DATABASE tempdb ADD FILE (NAME = tempdev2, FILENAME = 'D:\SQLDATA\tempdb2.ndf', SIZE=512MB, FILEGROWTH=128MB);
ALTER DATABASE tempdb ADD FILE (NAME = tempdev3, FILENAME = 'D:\SQLDATA\tempdb3.ndf', SIZE=512MB, FILEGROWTH=128MB);
ALTER DATABASE tempdb ADD FILE (NAME = tempdev4, FILENAME = 'D:\SQLDATA\tempdb4.ndf', SIZE=512MB, FILEGROWTH=128MB);

-- Ustaw AUTOGROW_ALL_FILES (SQL 2016+)
ALTER DATABASE tempdb MODIFY FILEGROUP [PRIMARY] AUTOGROW_ALL_FILES;
*/

-- Po restarcie sprawdź rozkład alokacji i powtórz test.
