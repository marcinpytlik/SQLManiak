-- Demonstration - Login and User
USE master;
GO

-- Step 1 - create the logins DemoLogin1 and DemoLogin2
CREATE LOGIN DemoLogin1 WITH PASSWORD = 'Pa$$w0rd';
CREATE LOGIN DemoLogin2 WITH PASSWORD = 'Pa$$w0rd';

-- Step 2 - examine DemoLogin1 and DemoLogin2 in sys.sql_logins
-- note the sid values, and that even though the users have the same password, it has a different password_hash value
SELECT * FROM sys.sql_logins WHERE name IN ('DemoLogin1','DemoLogin2');

-- Step 3 - add users to the TSQL database for these logins
USE TSQL;
GO
CREATE USER DemoUser1 FOR LOGIN DemoLogin1;
CREATE USER DemoUser2 FOR LOGIN DemoLogin2;

-- Step 4 - examine the users in sys.database_principals
-- note that the sid matches the values in sys.server_principals
SELECT * FROM TSQL.sys.database_principals WHERE name IN ('DemoUser1','DemoUser2');

-- Step 5 - script DemoLogin1 using SSMS
-- 1. In Object Explorer, then expand Security. Expand Logins.
-- 2. Right-click DemoUser1 and select Script Login as... > CREATE to > New Query Editor window
--    (if DemoLogin1 is not visible, right-click the Logins node and click Refresh)
-- 3. Examine the generated script. Note that the password is not correct

-- Step 6 - generate a script for DemoLogin1 and DemoLogin2 including SID and password hash
--          note that this script uses CONCAT and so is compatibile with SQL 2014 and later
SELECT	CONCAT('CREATE LOGIN [', name, '] WITH PASSWORD=', CONVERT(varchar(256),password_hash,1), ' HASHED,SID=',CONVERT(varchar(85),sid,1),';')
FROM	sys.sql_logins
WHERE	name IN ('DemoLogin1','DemoLogin2');
