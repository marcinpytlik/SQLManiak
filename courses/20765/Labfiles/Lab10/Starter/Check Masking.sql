-------------------------------------------------
-------------------------------------------------
-- 20765B Module 10 
-------------------------------------------------
-------------------------------------------------

-- Ensure the current database is AdventureWorksLT

-- Execute as TestUser
EXECUTE AS USER = 'TestUser';
GO

-- Test Dynamic Data Masking
SELECT * FROM SalesLT.Customer


-- Revert
REVERT
GO  


-- Test as Admin
SELECT * FROM SalesLT.Customer