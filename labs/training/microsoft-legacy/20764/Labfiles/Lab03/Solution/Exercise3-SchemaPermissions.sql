USE InternetSales;
GO

GRANT INSERT, UPDATE ON SCHEMA::Sales TO InternetSales_Managers;
GRANT SELECT ON Schema::Sales TO InternetSales_Managers; 
GRANT SELECT ON Schema::Sales TO InternetSales_Users;
GO
