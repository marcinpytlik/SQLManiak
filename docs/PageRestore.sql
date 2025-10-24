-- PAGE RESTORE – DEMO LAB
USE master;
GO

-- 1️⃣ Wymuszenie błędu (symulacja - tylko lab!)
DBCC WRITEPAGE ('AdventureWorks2022', 1, 200, 0, 1, 0x45, 1);
GO

-- 2️⃣ Diagnoza uszkodzenia
DBCC CHECKDB('AdventureWorks2022') WITH NO_INFOMSGS, ALL_ERRORMSGS;
GO
SELECT * FROM msdb.dbo.suspect_pages;
GO

-- 3️⃣ PAGE RESTORE
RESTORE DATABASE AdventureWorks2022
PAGE='1:200'
FROM DISK = 'D:\Backups\AdventureWorks2022_FULL.bak'
WITH NORECOVERY;
GO

-- 4️⃣ LOG RESTORE
RESTORE LOG AdventureWorks2022
FROM DISK = 'D:\Backups\AdventureWorks2022_LOG.trn'
WITH RECOVERY;
GO

-- 5️⃣ Weryfikacja
SELECT * FROM msdb.dbo.suspect_pages WHERE event_type = 4;
GO
DBCC CHECKDB('AdventureWorks2022');
