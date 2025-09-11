USE QS_Lab;
GO
-- baseline: parametr "popularny"
DECLARE @cid int = 100;
EXEC sp_executesql N'SELECT SUM(Amount) FROM dbo.Sales WHERE CustomerId = @cid AND CreateDate >= DATEADD(day,-30,GETDATE());', N'@cid int', @cid=@cid;
GO 50

-- baseline: parametr "rzadki"
DECLARE @cid int = 9999;
EXEC sp_executesql N'SELECT SUM(Amount) FROM dbo.Sales WHERE CustomerId = @cid AND CreateDate >= DATEADD(day,-30,GETDATE());', N'@cid int', @cid=@cid;
GO 50
