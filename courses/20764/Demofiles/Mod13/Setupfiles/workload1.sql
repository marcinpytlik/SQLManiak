USE InternetSales;
GO

DROP TABLE IF EXISTS ##stopload;
GO

WHILE OBJECT_ID('tempdb..##stopload') IS NULL
BEGIN
	SELECT c.categoryname, SUM(p.unitprice) ProductPrice, SUM(d.unitprice) PaidPrice, SUM(d.qty) Qty
	FROM Sales.Orders AS o
	JOIN Sales.OrderDetails AS d
	ON d.orderid = o.orderid
	JOIN Production.Products AS p
	ON p.productid = d.productid
	JOIN Production.Categories AS c
	ON c.categoryid = p.categoryid
	GROUP BY c.categoryname
	ORDER BY c.categoryname;

	WAITFOR DELAY '00:00:01';
END
