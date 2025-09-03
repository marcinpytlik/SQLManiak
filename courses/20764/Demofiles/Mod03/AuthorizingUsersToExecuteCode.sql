--Module 03 - Authorizing Users to Execute Code

-- Step 1: Use the AdventureWorks database.

USE AdventureWorks;
GO

-- Step 2: Change execution context to Mod03Login.

EXECUTE AS USER = 'Mod03Login';
GO

-- Step 3: Try to execute a stored procedure without specific permissions.
--         Note that execution fails and that the error message shows the 
--         lack of EXECUTE permission.

EXEC dbo.uspGetManagerEmployees
		@BusinessEntityID = 2;
GO

-- Step 4: Revert to Administrator security context.

REVERT;
GO

-- Step 5: Grant EXECUTE on the stored procedure to Mod03Login.

GRANT EXECUTE ON dbo.uspGetManagerEmployees
  TO Mod03Login;
GO

-- Step 6: Change execution context to Mod03Login.

EXECUTE AS USER = 'Mod03Login';
GO

-- Step 7: Try to execute a stored procedure without specific permissions.
--         Note that execution now works.

EXEC dbo.uspGetManagerEmployees
		@BusinessEntityID = 1;
GO

-- Step 8: While still Mod03Login, try to SELECT a value
--         from a function. Note that the error refers
--         to the EXECUTE permission, not the SELECT 
--         permission as it is the execution of the function
--         that is being denied, not the selection of the 
--         value from the function.

SELECT dbo.ufnGetStock(1);
GO

-- Step 9: Revert to Administrator security context.

REVERT;
GO

-- Step 10: Grant execute permission on the function 
--          to public. Note that this is a common
--          permission grant for generic functions
--          within a database.

GRANT EXECUTE ON dbo.ufnGetStock TO public;
GO

-- Step 11: Attempt to access the function as Mod03Login again.
--          Note that it now works.

EXECUTE AS USER = 'Mod03Login';
GO

SELECT dbo.ufnGetStock(1);
GO

REVERT;
GO
