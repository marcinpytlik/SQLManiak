
-- 01-transaction-demo.sql
USE ARIES_Demo;
GO

BEGIN TRAN;
INSERT INTO dbo.LogDemo(Info) VALUES (N'Pierwszy wpis');
INSERT INTO dbo.LogDemo(Info) VALUES (N'Drugi wpis');
-- transakcja celowo niezatwierdzona
ROLLBACK TRAN;

SELECT * FROM dbo.LogDemo;

-- podgląd wpisów logu (tylko do testów)
SELECT [Current LSN], [Operation], [Transaction ID], [Context], [Page ID]
FROM fn_dblog(NULL, NULL)
WHERE [Transaction Name] IS NOT NULL;
