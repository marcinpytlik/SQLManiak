-- Module 10 Demo 5

-- Connect this query window to Azure, and then to a copy of AdventureWorksLT, before you continue

DECLARE @i INT = 1
WHILE @i < 200
BEGIN
	SELECT * FROM SalesLT.Customer
	SET @i += 1
END
