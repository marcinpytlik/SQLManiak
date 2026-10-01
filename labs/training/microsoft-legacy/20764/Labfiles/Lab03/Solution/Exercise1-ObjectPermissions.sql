USE InternetSales;
GO

GRANT SELECT ON Products.vProductCatalog TO WebApplicationSvc;
GRANT INSERT ON Sales.SalesOrderHeader TO WebApplicationSvc;
GRANT INSERT ON Sales.SalesOrderDetail TO WebApplicationSvc;
GO

GRANT SELECT ON Customers.Customer TO Database_Managers;
GRANT SELECT ON Customers.Customer TO InternetSales_Managers;
GRANT SELECT ON Customers.Customer TO InternetSales_Users;
GO

DENY SELECT ON Customers.Customer TO Database_Managers;
GO

REVOKE SELECT ON Customers.Customer TO Database_Managers;
GO