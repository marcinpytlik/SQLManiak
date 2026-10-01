USE [master]
GO

CREATE TABLE ##stopload (id int);

USE [AdventureWorks]
GO


EXEC sys.sp_dropextendedproperty @name=N'MS_Description' , @level0type=N'SCHEMA',@level0name=N'Sales', @level1type=N'TABLE',@level1name=N'SalesOrderDetail', @level2type=N'CONSTRAINT',@level2name=N'PK_SalesOrderDetail_SalesOrderID_SalesOrderDetailID'
GO

ALTER TABLE [Sales].[SalesOrderDetail] DROP CONSTRAINT [PK_SalesOrderDetail_SalesOrderID_SalesOrderDetailID] WITH ( ONLINE = OFF )
GO

EXEC sys.sp_dropextendedproperty @name=N'MS_Description' , @level0type=N'SCHEMA',@level0name=N'Sales', @level1type=N'TABLE',@level1name=N'SalesOrderHeader', @level2type=N'CONSTRAINT',@level2name=N'FK_SalesOrderHeader_SalesPerson_SalesPersonID'
GO

ALTER TABLE [Sales].[SalesOrderHeader] DROP CONSTRAINT [FK_SalesOrderHeader_SalesPerson_SalesPersonID]
GO

EXEC sys.sp_dropextendedproperty @name=N'MS_Description' , @level0type=N'SCHEMA',@level0name=N'Production', @level1type=N'TABLE',@level1name=N'Product', @level2type=N'CONSTRAINT',@level2name=N'FK_Product_ProductSubcategory_ProductSubcategoryID'
GO

ALTER TABLE [Production].[Product] DROP CONSTRAINT [FK_Product_ProductSubcategory_ProductSubcategoryID]
GO

ALTER INDEX ALL ON [AdventureWorks].[Production].[Product] REBUILD;
GO
ALTER INDEX ALL ON [AdventureWorks].[Sales].[SalesOrderHeader] REBUILD;
GO
ALTER INDEX ALL ON [AdventureWorks].[Sales].[SalesOrderDetail] REBUILD; 

USE [master]
GO

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
