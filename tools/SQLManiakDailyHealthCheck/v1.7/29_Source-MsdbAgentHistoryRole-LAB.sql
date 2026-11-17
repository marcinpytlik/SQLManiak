/* Test 36D: Run on Docker LAB 15434 and 15435 (as SQL administrator).
   Target 15434: lab_1; target 15435: lab_2.
   Creates an msdb role for two read-only Agent history tables.
*/
USE msdb;
GO
SET NOCOUNT ON;
DECLARE @Login sysname=N'dhc_source_collector_lab_1'; -- change to lab_2 on 15435
IF @Login NOT IN (N'dhc_source_collector_lab_1',N'dhc_source_collector_lab_2')
 THROW 51310,'Unsupported LAB source user.',1;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name=@Login AND type='S')
 THROW 51311,'Required msdb database user not found.',1;
IF EXISTS (
 SELECT 1 FROM sys.database_principals WHERE name=N'dhc_agent_history_reader' AND type<>'R'
)
 THROW 51312,'Target role name exists with incompatible type.',1;
IF DATABASE_PRINCIPAL_ID(N'dhc_agent_history_reader') IS NULL
 EXEC(N'CREATE ROLE [dhc_agent_history_reader] AUTHORIZATION [dbo];');
GRANT SELECT ON OBJECT::dbo.sysjobschedules TO [dhc_agent_history_reader];
GRANT SELECT ON OBJECT::dbo.sysjobhistory TO [dhc_agent_history_reader];

IF NOT EXISTS (
 SELECT 1 FROM sys.database_role_members AS rm
 JOIN sys.database_principals AS rp ON rp.principal_id=rm.role_principal_id
 JOIN sys.database_principals AS mp ON mp.principal_id=rm.member_principal_id
 WHERE rp.name=N'dhc_agent_history_reader' AND mp.name=@Login
)
BEGIN
 DECLARE @sql nvarchar(max)=N'ALTER ROLE [dhc_agent_history_reader] ADD MEMBER '+QUOTENAME(@Login)+N';';
 EXEC sys.sp_executesql @sql;
END;
SELECT rp.name AS RoleName,OBJECT_NAME(p.major_id) AS ObjectName,p.permission_name,p.state_desc
FROM sys.database_permissions AS p
JOIN sys.database_principals AS rp ON rp.principal_id=p.grantee_principal_id
WHERE rp.name=N'dhc_agent_history_reader'
ORDER BY ObjectName,p.permission_name;
SELECT rp.name AS RoleName,mp.name AS MemberName
FROM sys.database_role_members AS rm
JOIN sys.database_principals AS rp ON rp.principal_id=rm.role_principal_id
JOIN sys.database_principals AS mp ON mp.principal_id=rm.member_principal_id
WHERE rp.name=N'dhc_agent_history_reader';
GO
/* Verify UNDER the dedicated non-sysadmin source login:
 USE msdb;
 SELECT TOP (0) job_id FROM dbo.sysjobschedules;
 SELECT TOP (0) instance_id FROM dbo.sysjobhistory;
*/
