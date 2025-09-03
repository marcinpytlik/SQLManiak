-- Code to create server roles, logins and users

-- Step A: use master
USE AdventureWorks;
GO

-- Step B:  Create two server roles
CREATE SERVER ROLE MyExtServerRole;
CREATE SERVER ROLE MyServerRole;
GO

-- Step C: Create a Login
CREATE LOGIN MyLogin WITH PASSWORD = 'Pa$$w0rd', CHECK_POLICY = OFF;
GO

-- Step D: Add the Login to the server roles
ALTER SERVER ROLE MyServerRole ADD MEMBER MyLogin;
ALTER SERVER ROLE MyExtServerRole ADD MEMBER MyServerRole;
GO

-- Step E: Create database roles in the master database
CREATE ROLE MyExtDatabaseRole;
CREATE ROLE MyDatabaseRole;
GO

-- Step F: Create a new user using the login
CREATE USER DemoUser FOR LOGIN MyLogin;
GO

-- Step G: Add the Login to the server roles
ALTER ROLE MyDatabaseRole ADD MEMBER DemoUser;
ALTER ROLE MyExtDatabaseRole ADD MEMBER MyDatabaseRole;
GO

-- Step H: View the tokens
EXECUTE AS LOGIN = 'MyLogin'
	SELECT * FROM sys.user_token;
	SELECT * FROM sys.login_token;
REVERT
GO

-- Step I: Undo all changes
ALTER ROLE MyDatabaseRole DROP MEMBER DemoUser;
ALTER ROLE MyExtDatabaseRole DROP MEMBER MyDatabaseRole;

DROP ROLE MyDatabaseRole;
DROP ROLE MyExtDatabaseRole;

ALTER SERVER ROLE MyServerRole DROP MEMBER MyLogin;
ALTER SERVER ROLE MyExtServerRole DROP MEMBER MyServerRole;

DROP USER DemoUser;
DROP LOGIN MyLogin;


DROP SERVER ROLE MyExtServerRole;
DROP SERVER ROLE MyServerRole;

GO


