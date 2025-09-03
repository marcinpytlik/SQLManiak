-- Module 2 - Demo 4

-- Step 1 - create an application role
USE AdventureWorks;
GO

CREATE APPLICATION ROLE purchase_order WITH PASSWORD = 'Pa$$w0rd';
GO

-- Step 2 - grant the role select permissions on the Purchasing schema
GRANT SELECT ON SCHEMA::Purchasing TO purchase_order;
GO

-- Step 3 - before activating the application role, demonstrate
-- that you can SELECT from Sales.Customer
SELECT TOP (10) * FROM Sales.Customer;
GO

-- Step 4 - activate the application role
-- the cookie is stored in a temporary table to persist it across batch seperators
DROP TABLE IF EXISTS #cookie
DECLARE @cookie_store varbinary(8000)

EXEC sp_setapprole  @rolename = N'purchase_order', 
					@password = N'Pa$$w0rd', 
					@fCreateCookie = true, 
					@cookie = @cookie_store OUTPUT;

SELECT @cookie_store AS cookie
INTO #cookie
GO

-- Step 5 - demonstrate that, once the application role is active,
-- the user cannot access objects to which the role has no permissions
-- (This command will generate an error)
SELECT TOP (10) * FROM Sales.Customer;
GO
-- However, the user has access to objects which the role has permission to access
SELECT TOP (10) * FROM Purchasing.ShipMethod;
GO


-- Step 6 - show that the user's identity is still accessible from SUSER_SNAME() and SUSER_NAME(),
-- but that USER_NAME is the application role
SELECT	SUSER_SNAME() AS suser_sname, 
		SUSER_NAME() AS suser_name, 
		USER_NAME() AS user_name;
GO

-- Step 7 - show that the user has no access to other databases
-- (This command will generate an error)
SELECT * from semanticsdb.dbo.version;

-- Step 8 - exit the application role
DECLARE @cookie varbinary(8000) = (SELECT TOP (1) cookie FROM #cookie);
EXEC sp_unsetapprole @cookie;
GO

-- Step 9 - demonstrate the current security context
SELECT	SUSER_SNAME() AS suser_sname, 
		SUSER_NAME() AS suser_name, 
		USER_NAME() AS user_name;
GO

-- Step 10 - remove the application role
DROP APPLICATION ROLE purchase_order;
GO
