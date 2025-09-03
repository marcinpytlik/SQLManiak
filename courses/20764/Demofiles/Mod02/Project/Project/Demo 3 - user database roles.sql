-- Module 2 - Demo 3

-- Step 1 - create a user-defined database role
USE AdventureWorks;
GO

CREATE ROLE human_resources_reader;
GO

-- Step 2 - grant SELECT permission on the HumanResources schema to the role
GRANT SELECT ON SCHEMA::HumanResources TO human_resources_reader;
GO

-- Step 3 - verify role permissions
SELECT	dpr.name AS principal_name, dpe.permission_name, 
		dpe.class_desc, sch.name AS object_name
FROM sys.database_permissions AS dpe
JOIN sys.database_principals AS dpr
ON dpr.principal_id = dpe.grantee_principal_id
LEFT JOIN sys.schemas AS sch
ON sch.schema_id = dpe.major_id
AND dpe.class = 3
WHERE dpr.name = 'human_resources_reader';
GO

-- Step 4 - add two users to the human_resources_reader role
ALTER ROLE human_resources_reader ADD MEMBER stephen0;
ALTER ROLE human_resources_reader ADD MEMBER jae0;
GO

-- Step 5 - verify role membership
SELECT rdp.name AS role_name, rdm.name AS member_name
FROM sys.database_role_members AS rm
JOIN sys.database_principals AS rdp
ON rdp.principal_id = rm.role_principal_id
JOIN sys.database_principals AS rdm
ON rdm.principal_id = rm.member_principal_id
WHERE rdp.name = 'human_resources_reader'
ORDER BY role_name, member_name;
GO

-- Step 6 - clean up demonstration objects
ALTER ROLE human_resources_reader DROP MEMBER stephen0;
ALTER ROLE human_resources_reader DROP MEMBER jae0;

IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'human_resources_reader' AND type = 'R')
	DROP ROLE human_resources_reader;
GO
