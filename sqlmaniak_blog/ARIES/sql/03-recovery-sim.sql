
-- 03-recovery-sim.sql
USE ARIES_Demo;
GO

BEGIN TRAN Demo1;
INSERT INTO dbo.LogDemo(Info) VALUES (N'Transakcja A - zaczęta');
WAITFOR DELAY '00:00:02';
COMMIT TRAN Demo1;

BEGIN TRAN Demo2;
INSERT INTO dbo.LogDemo(Info) VALUES (N'Transakcja B - zaczęta');
-- nie zatwierdzamy, symulujemy awarię
ROLLBACK TRAN Demo2;

-- log entries
SELECT TOP 50 [Current LSN], [Operation], [Transaction ID], [Transaction Name], [Context]
FROM fn_dblog(NULL, NULL)
ORDER BY [Current LSN] DESC;
