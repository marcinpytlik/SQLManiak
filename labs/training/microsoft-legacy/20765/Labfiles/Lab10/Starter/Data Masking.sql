-------------------------------------------------
-------------------------------------------------
-- 20765B Module 10 
-------------------------------------------------
-------------------------------------------------

--Create Test User
CREATE USER TestUser WITHOUT LOGIN; 
ALTER ROLE db_datareader ADD MEMBER TestUser;

-- Execute as TestUser
EXECUTE AS USER = 'TestUser';
GO


-- Test Dynamic Data Masking
SELECT * FROM SalesLT.Customer


-- Revert
REVERT
GO  


