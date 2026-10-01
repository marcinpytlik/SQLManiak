
DROP TABLE IF EXISTS ##stopload;
GO

WHILE OBJECT_ID('tempdb..##stopload') IS NULL
BEGIN

	SELECT total.Name,  total.categoryname, SUM(total.PaidPrice) PaidPrice, SUM(total.ProductPrice) ProductPrice, SUM(total.Qty) Quantity FROM
	(
	SELECT emp.FirstName + ' ' + emp.LastName as [Name], sub.Name categoryname, p.ListPrice ProductPrice, d.unitprice PaidPrice, d.OrderQty Qty
	FROM AdventureWorks.Sales.SalesOrderHeader AS o
	JOIN AdventureWorks.Sales.SalesPerson as personid
	ON o.SalesPersonID = personid.BusinessEntityID
	JOIN AdventureWorks.Person.Person emp
	ON emp.BusinessEntityID = personid.BusinessEntityID
	JOIN AdventureWorks.Sales.SalesOrderDetail AS d
	ON d.SalesOrderID = o.SalesOrderID
	JOIN AdventureWorks.Production.Product AS p
	ON p.productid = d.productid
	JOIN AdventureWorks.[Production].[ProductSubcategory] AS sub
	ON sub.ProductSubcategoryID = p.ProductSubcategoryID
	) as total
	GROUP BY name, categoryname
	ORDER BY name, Quantity DESC;

	WAITFOR DELAY '00:00:01';
END
