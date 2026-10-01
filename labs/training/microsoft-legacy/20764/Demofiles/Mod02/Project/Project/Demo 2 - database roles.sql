-- Module 2 - Demo 2

-- Connect this query window to the master database on Azure

-- Step 1 - create a new login for use in this demo
IF NOT EXISTS (SELECT * FROM sys.sql_logins WHERE name = 'demo_login_3')
	CREATE LOGIN demo_login_3 WITH PASSWORD = 'Pa$$w0rd';
GO

-- Step 2 - connect this query window to your copy of AdventureWorksLT, 
-- then create a new database user for use in this demo
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'demo_user_3')
	DROP USER demo_user_3
GO
CREATE USER demo_user_3 FOR LOGIN demo_login_3;
GO

-- Step 3 - display the hierarchy of database permissions
WITH recCTE
AS
(
	SELECT	permission_name, covering_permission_name AS parent_permission, 
			parent_covering_permission_name AS parent_server_permission, 
			1 AS hierarchy_level
	FROM sys.fn_builtin_permissions('DATABASE') 
	WHERE covering_permission_name = ''

	UNION ALL

	SELECT	bp.permission_name, bp.covering_permission_name, 
			bp.parent_covering_permission_name AS parent_server_permission, 
			hierarchy_level + 1 AS hierarchy_level
	FROM recCTE AS r
	CROSS APPLY sys.fn_builtin_permissions('DATABASE') AS bp
	WHERE bp.covering_permission_name = r.permission_name
)
SELECT * FROM recCTE
ORDER BY hierarchy_level, permission_name;
GO

-- Step 4 - demonstrate that the user is a member of the public database role by default
EXECUTE AS USER = 'demo_user_3'
SELECT IS_MEMBER('public') AS is_public_member
REVERT
GO

-- Step 5 - add the demo user to the db_datareader role
-- and the db_ddladmin role
ALTER ROLE db_datareader ADD MEMBER demo_user_3;
GO
ALTER ROLE db_ddladmin ADD MEMBER demo_user_3;
GO

-- Step 6 - view role memberships for the demo user
SELECT rdp.name AS role_name, rdm.name AS member_name
FROM sys.database_role_members AS rm
JOIN sys.database_principals AS rdp
ON rdp.principal_id = rm.role_principal_id
JOIN sys.database_principals AS rdm
ON rdm.principal_id = rm.member_principal_id
WHERE rdm.name = 'demo_user_3'
ORDER BY role_name, member_name;

-- Step 7 - remove the demo objects
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'demo_user_3')
	DROP USER demo_user_3
GO

-- Step 8 - connect this query window to the master database, then continue
IF EXISTS (SELECT * FROM sys.sql_logins WHERE name = 'demo_login_3')
	DROP LOGIN demo_login_3;
GO
