START sqlcmd -S MIA-SQL -E -d InternetSales -q "BEGIN TRAN; UPDATE Sales.Orders SET shipname = N'Ship to Department 4Q' WHERE orderid = 11071;"
START sqlcmd -S MIA-SQL -E -d InternetSales -Q "WAITFOR DELAY '00:00:02'; BEGIN TRAN; SELECT * FROM Sales.Orders AS so WITH (REPEATABLEREAD) JOIN Sales.OrderDetails AS sd ON sd.orderid = so.orderid; COMMIT;"
START sqlcmd -S MIA-SQL -E -d InternetSales -Q "WAITFOR DELAY '00:00:05'; UPDATE Sales.Orders SET shippeddate = '2016-01-01' WHERE orderid = 11054;"

