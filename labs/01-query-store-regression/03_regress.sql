USE QS_Lab;
GO
-- Wymuś sniffing/regresję: wyczyść cache i odśwież staty wybiórczo
DBCC FREEPROCCACHE WITH NO_INFOMSGS;
UPDATE STATISTICS dbo.Sales WITH FULLSCAN;

-- Uruchom serię z nietypowym parametrem, aby "zaprogramować" plan
DECLARE @cid int = 9999;  -- rzadki
EXEC sp_executesql N'SELECT SUM(Amount) FROM dbo.Sales WHERE CustomerId = @cid AND CreateDate >= DATEADD(day,-30,GETDATE());', N'@cid int', @cid=@cid;
GO 10

-- Teraz wywołaj popularny parametr i obserwuj ewentualną regresję czasu/IO
DECLARE @cid int = 100;
EXEC sp_executesql N'SELECT SUM(Amount) FROM dbo.Sales WHERE CustomerId = @cid AND CreateDate >= DATEADD(day,-30,GETDATE());', N'@cid int', @cid=@cid;
GO 10
