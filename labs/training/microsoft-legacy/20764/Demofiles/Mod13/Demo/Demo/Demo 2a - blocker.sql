-- Module 13 - Demo 2 - File 1
USE InternetSales;
GO
BEGIN TRANSACTION
	UPDATE HR.Employees
	SET firstname = 'Donald'
	WHERE empid = 2;
	