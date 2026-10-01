USE InternetSales;
GO

GRANT EXECUTE ON Products.ChangeProductPrice TO InternetSales_Managers;
GO

SELECT ListPrice from Products.Product WHERE ProductID<10;