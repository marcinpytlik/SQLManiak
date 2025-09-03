--Module 03 - Authorizing User Access to Objects

-- Step 1: Use the AdventureWorks database and create a user for the demonstration.

USE master;
GO

CREATE LOGIN Mod03Login WITH PASSWORD = 'Pa$$w0rd', CHECK_POLICY = OFF;
GO

USE AdventureWorks;
GO

CREATE USER Mod03Login FOR LOGIN Mod03Login;
GO



-- Step 2: Query the full list of server principals. Note that this
--         list includes type C principals (certificate_mapped_logins).
--         These logins are created by SQL Server, have names enclosed
--         in ## and should not be deleted. They are logins that are
--         created from certificates. (Creating logins from certificates
--         is an advanced topic that is out of scope for this course).

SELECT * FROM sys.server_principals;
GO

-- Step 3: Query the full list of database principals. Note that this
--         list can include windows users, SQL users, database roles,
--         application roles, and users created from certificates. (The
--         creation of database users from certificates is also an 
--         advanced topic that is out of scope for this course).

SELECT * FROM sys.database_principals;
GO

-- Step 4: Grant SELECT permission on the Production.Product table
--         to Mod03Login.

GRANT SELECT ON Production.Product TO Mod03Login;
GO

-- Step 5: Change the execution context to the Mod03Login context.

EXECUTE AS USER = 'Mod03Login';
GO

-- Step 6: Try to SELECT from the Production.Product and 
--         Production.ProductInventory tables. Note that you are
--         able to SELECT from Production.Product but not
--         from Production.ProductInventory. The default is that
--         users cannot perform any action apart from 
--         actions they have explicitly been permitted to
--         perform.

SELECT * FROM Production.Product;
GO

SELECT * FROM Production.ProductInventory;
GO

-- Step 7: Revert to the Administrator security context.

REVERT;
GO

-- Step 8: Grant SELECT only on the Shelf and Bin
--         columns in Production.ProductInventory to Mod03Login.

GRANT SELECT ON Production.ProductInventory
  (Shelf, Bin)
  TO Mod03Login;
GO

-- Step 9: Change the execution context to the Mod03Login context.

EXECUTE AS USER = 'Mod03Login';
GO

-- Step 10: Try to SELECT from the Shelf and Bin columns
--          and also try to SELECT all columns from Production.ProductInventory.
--          For the first query, use DISTINCT to remove duplicate values.
--          Note that the first query works. Note also, however, 
--          that an error message is returned for each column that
--          the user is not permitted to access, in the second query.

SELECT DISTINCT Shelf, Bin FROM Production.ProductInventory;
GO

SELECT * FROM Production.ProductInventory;
GO

-- Step 11: Revert to the Administrator security context.

REVERT;
GO