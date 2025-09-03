-- Module 2 - Demo 1

-- Step 1 - display the list of server-level permissions in their hierarchy
-- Execute:
WITH recCTE
AS
(
	SELECT	permission_name, covering_permission_name AS parent_permission, 
			1 AS hierarchy_level
	FROM sys.fn_builtin_permissions('SERVER') 
	WHERE permission_name = 'CONTROL SERVER'

	UNION ALL

	SELECT	bp.permission_name, bp.covering_permission_name, 
			hierarchy_level + 1 AS hierarchy_level
	FROM recCTE AS r
	CROSS APPLY sys.fn_builtin_permissions('SERVER') AS bp
	WHERE bp.covering_permission_name = r.permission_name
)
SELECT * FROM recCTE
ORDER BY hierarchy_level, permission_name;

-- Step 2 - create two logins for use in the demonstration
-- Execute:
CREATE LOGIN demo_login_1 WITH PASSWORD = 'Pa$$w0rd';
CREATE LOGIN demo_login_2 WITH PASSWORD = 'Pa$$w0rd';
GO

-- Step 3 - show that a login is always a member of the public role
-- Execute:
SELECT IS_SRVROLEMEMBER ('public', 'demo_login_1')

-- Step 4 - demonstrate the default server permissions of a new login
-- Execute:
EXECUTE AS LOGIN = 'demo_login_1'
SELECT * FROM sys.fn_my_permissions (NULL, 'SERVER');
REVERT

-- Step 5 - add demo_login_1 to the diskadmin fixed server role
-- Execute: 
ALTER SERVER ROLE diskadmin ADD MEMBER demo_login_1;
GO

-- Step 6 - verify that demo_login_1 is a member of diskadmin
-- Execute:
SELECT spr.name AS role_name, spm.name AS member_name
FROM sys.server_role_members AS rm
JOIN sys.server_principals AS spr
ON spr.principal_id = rm.role_principal_id
JOIN sys.server_principals AS spm
ON spm.principal_id = rm.member_principal_id
WHERE spm.name = 'demo_login_1'
ORDER BY role_name, member_name;
GO

-- Step 7 - create a user-defined server role
-- Execute:
CREATE SERVER ROLE demo_role AUTHORIZATION sa;
GO

-- Step 8 - grant the ALTER TRACE and ADMINISTER BULK OPERATIONS roles to demo_role
-- Execute:
GRANT ALTER TRACE TO demo_role;
GRANT ADMINISTER BULK OPERATIONS TO demo_role;
GO

-- Step 9 - make demo_login_2 a member of the demo_role
-- Execute:
ALTER SERVER ROLE demo_role ADD MEMBER demo_login_2;
GO

-- Step 10 - verify that demo_login_2 is a member of demo_role
-- Execute:
SELECT spr.name AS role_name, spm.name AS member_name
FROM sys.server_role_members AS rm
JOIN sys.server_principals AS spr
ON spr.principal_id = rm.role_principal_id
JOIN sys.server_principals AS spm
ON spm.principal_id = rm.member_principal_id
WHERE spm.name = 'demo_login_2'
ORDER BY role_name, member_name;
GO

-- Step 11 - demonstrate the permissions of demo_login_2
-- Execute:
EXECUTE AS LOGIN = 'demo_login_2'
SELECT * FROM sys.fn_my_permissions (NULL, 'SERVER');
REVERT
GO

-- Step 12 - clean up demonstration objects
-- Execute:
IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'demo_login_1' AND type = 'S')
	DROP LOGIN demo_login_1;

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'demo_login_2' AND type = 'S')
	DROP LOGIN demo_login_2;

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'demo_role' AND type = 'R')
	DROP SERVER ROLE demo_role;
GO
