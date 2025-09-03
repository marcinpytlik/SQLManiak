-- Creating a Partially Contained Database

-- STEP A. View the current server containment attribute, returns ‘1’ for enabled and ‘0’ for disabled:
USE master
GO

SELECT value_in_use, description FROM sys.configurations WHERE name = 'contained database authentication'
GO

-- STEP B Disable containment and view the new value:
EXEC sys.sp_configure N'contained database authentication',0
GO

RECONFIGURE      
GO

SELECT value_in_use, description FROM sys.configurations WHERE name = 'contained database authentication'
GO

-- STEP C. Enable containment and view the new value:
EXEC sys.sp_configure N'contained database authentication',1
GO 
RECONFIGURE      
GO

SELECT value_in_use, description FROM sys.configurations WHERE name = 'contained database authentication'
GO

-- STEP D. Create a contained database
CREATE DATABASE PClientData
CONTAINMENT = PARTIAL;
GO

-- STEP E. Create and view contained users
USE PClientData
GO
CREATE USER ClientUser1 WITH PASSWORD = 'Pa$$w0rd'
CREATE USER ClientUser2 WITH PASSWORD = 'Pa$$w0rd'
CREATE USER ClientUser3 WITH PASSWORD = 'Pa$$w0rd'

SELECT * FROM sys.database_principals where name like 'Client%'
GO

-- STEP F. Remove the partially contained database and users
USE master
GO
ALTER DATABASE PClientData SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO
DROP DATABASE PClientData
GO

