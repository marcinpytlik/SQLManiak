USE InternetSales;
WHILE 1 = 1
	INSERT InternetSales.dbo.CustomerLog (Customername, Email)
	SELECT FirstName + Lastname, EmailAddress
	FROM InternetSales.Customers.Customer;
