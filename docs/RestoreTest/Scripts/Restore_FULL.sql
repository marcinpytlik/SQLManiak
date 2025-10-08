-- Restore FULL to DemoDB_Test (files moved to D:\SQLData / D:\SQLLog)
-- Uwaga: Zmień nazwy plików logicznych jeśli różnią się w źródłowej bazie.
RESTORE DATABASE [DemoDB_Test]
FROM DISK = N'D:\Backup\DemoDB_FULL.bak'
WITH MOVE N'DemoDB'     TO N'D:\SQLData\DemoDB_Test.mdf',
     MOVE N'DemoDB_log' TO N'D:\SQLLog\DemoDB_Test.ldf',
     REPLACE,
     NORECOVERY; -- pozostawiamy NORECOVERY, aby ewentualnie dołożyć DIFF/LOG
