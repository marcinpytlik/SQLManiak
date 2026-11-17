/* Test 36B: isolated Docker LAB autogrowth permission
   On 127.0.0.1,15434 or 127.0.0.1,15435, run as administrator.
   SQLCMD mode: set the login name below for the actual target.
   ALTER TRACE is broad: it can manage traces, not just read autogrowth.
   Do not execute unchanged against production instances.
*/
USE master;
GO
DECLARE @Login sysname=N'dhc_source_collector_lab_1'; -- Target 15434
-- For 15435 replace with: N'dhc_source_collector_lab_2'
DECLARE @Role sysname=N'dhc_autogrowth_reader';
IF @Login NOT IN (N'dhc_source_collector_lab_1',N'dhc_source_collector_lab_2')
 THROW 51301,'Unsupported LAB login.',1;

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name=@Login AND type='S')
 THROW 51302,'Expected dedicated LAB source login not present.',1;

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name=@Role AND type<>'R')
 THROW 51303,'A server principal with target role name already exists but is not a server role.',1;

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name=@Role AND type='R')
 EXEC(N'CREATE SERVER ROLE [dhc_autogrowth_reader] AUTHORIZATION [sa];');

GRANT ALTER TRACE TO [dhc_autogrowth_reader];

IF NOT EXISTS (
 SELECT 1 FROM sys.server_role_members m
 JOIN sys.server_principals r ON r.principal_id=m.role_principal_id
 JOIN sys.server_principals u ON u.principal_id=m.member_principal_id
 WHERE r.name=@Role AND u.name=@Login
)
BEGIN
 DECLARE @stmt nvarchar(max)=N'ALTER SERVER ROLE '+QUOTENAME(@Role)+
     N' ADD MEMBER '+QUOTENAME(@Login)+N';';
 EXEC sys.sp_executesql @stmt;
END;

SELECT
 r.name AS RoleName,
 p.permission_name AS PermissionName,
 p.state_desc AS StateDesc
FROM sys.server_permissions p
JOIN sys.server_principals r ON r.principal_id=p.grantee_principal_id
WHERE r.name=@Role;

SELECT r.name AS RoleName,u.name AS MemberLogin
FROM sys.server_role_members m
JOIN sys.server_principals r ON r.principal_id=m.role_principal_id
JOIN sys.server_principals u ON u.principal_id=m.member_principal_id
WHERE r.name=@Role;
GO
/* Verify with an actual connection AS THE DEDICATED LOGIN:
 SELECT SUSER_SNAME() AS LoginName,
        IS_SRVROLEMEMBER('dhc_autogrowth_reader') AS IsRoleMember,
        HAS_PERMS_BY_NAME(NULL,NULL,'ALTER TRACE') AS CanAlterTrace,
        IS_SRVROLEMEMBER('sysadmin') AS IsSysadmin;
 SELECT id,status,is_default FROM sys.traces;
*/
