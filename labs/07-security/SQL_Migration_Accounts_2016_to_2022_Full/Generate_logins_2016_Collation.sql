/* Generate_Logins_2016.sql — v2.1 (collation-safe, temp table)
*/
USE master;
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#Src') IS NOT NULL DROP TABLE #Src;

CREATE TABLE #Src
(
    principal_id           int         NOT NULL,
    sid                    varbinary(85) NOT NULL,
    name                   sysname     NOT NULL,
    type                   char(1)     NOT NULL,     -- S/U/G
    type_desc              nvarchar(60) NOT NULL,
    is_disabled            bit         NOT NULL,
    password_hash          varbinary(256) NULL,
    is_policy_checked      bit         NULL,
    is_expiration_checked  bit         NULL,
    default_database_name  sysname     NULL,
    default_language_name  sysname     NULL
);

INSERT INTO #Src (principal_id,sid,name,type,type_desc,is_disabled,password_hash,is_policy_checked,is_expiration_checked,default_database_name,default_language_name)
SELECT sp.principal_id, sp.sid, sp.name, sp.type, sp.type_desc, sp.is_disabled,
       sl.password_hash, sl.is_policy_checked, sl.is_expiration_checked,
       sp.default_database_name, sp.default_language_name
FROM sys.server_principals AS sp
LEFT JOIN sys.sql_logins    AS sl ON sl.principal_id = sp.principal_id
WHERE sp.type IN ('S','U','G')
  AND sp.name COLLATE DATABASE_DEFAULT NOT IN (N'sa')
  AND sp.name COLLATE DATABASE_DEFAULT NOT LIKE N'##MS_%##' ESCAPE N'\'
  AND sp.name COLLATE DATABASE_DEFAULT NOT LIKE N'NT SERVICE\%'
  AND sp.name COLLATE DATABASE_DEFAULT NOT LIKE N'NT AUTHORITY\%';

--------------------------------------------------------------------------------
-- 1) CREATE LOGIN
--------------------------------------------------------------------------------
SELECT
    CASE s.type
        WHEN 'S' THEN
            N'CREATE LOGIN ' + CAST(QUOTENAME(s.name) AS nvarchar(4000)) COLLATE DATABASE_DEFAULT + N' WITH ' +
            N'PASSWORD = ' + CASE WHEN s.password_hash IS NOT NULL
                                  THEN N'0x' + CONVERT(nvarchar(256), s.password_hash, 2) + N' HASHED'
                                  ELSE N'''<<SET_PASSWORD_AFTER_MIGRATION>>'''
                             END + N', ' +
            N'SID = 0x' + CONVERT(nvarchar(256), s.sid, 2) + N', ' +
            N'DEFAULT_DATABASE = ' + CAST(QUOTENAME(COALESCE(NULLIF(s.default_database_name,''),'master')) AS nvarchar(4000)) COLLATE DATABASE_DEFAULT + N', ' +
            N'DEFAULT_LANGUAGE = ' + CAST(QUOTENAME(COALESCE(NULLIF(s.default_language_name,''),'us_english')) AS nvarchar(4000)) COLLATE DATABASE_DEFAULT + N', ' +
            N'CHECK_POLICY = ' + CASE WHEN s.is_policy_checked = 1 THEN 'ON' ELSE 'OFF' END + N', ' +
            N'CHECK_EXPIRATION = ' + CASE WHEN s.is_expiration_checked = 1 THEN 'ON' ELSE 'OFF' END + N';'
        WHEN 'U' THEN
            N'CREATE LOGIN ' + CAST(QUOTENAME(s.name) AS nvarchar(4000)) COLLATE DATABASE_DEFAULT + N' FROM WINDOWS WITH ' +
            N'SID = 0x' + CONVERT(nvarchar(256), s.sid, 2) + N', ' +
            N'DEFAULT_DATABASE = ' + CAST(QUOTENAME(COALESCE(NULLIF(s.default_database_name,''),'master')) AS nvarchar(4000)) COLLATE DATABASE_DEFAULT + N', ' +
            N'DEFAULT_LANGUAGE = ' + CAST(QUOTENAME(COALESCE(NULLIF(s.default_language_name,''),'us_english')) AS nvarchar(4000)) COLLATE DATABASE_DEFAULT + N';'
        WHEN 'G' THEN
            N'CREATE LOGIN ' + CAST(QUOTENAME(s.name) AS nvarchar(4000)) COLLATE DATABASE_DEFAULT + N' FROM WINDOWS WITH ' +
            N'SID = 0x' + CONVERT(nvarchar(256), s.sid, 2) + N';'
    END AS [-- CreateLogins]
FROM #Src AS s
ORDER BY s.type, s.name;

--------------------------------------------------------------------------------
-- 2) DISABLE logins
--------------------------------------------------------------------------------
SELECT
    N'ALTER LOGIN ' + CAST(QUOTENAME(s.name) AS nvarchar(4000)) COLLATE DATABASE_DEFAULT + N' DISABLE;' AS [-- DisabledLogins]
FROM #Src AS s
WHERE s.is_disabled = 1
ORDER BY s.name;

--------------------------------------------------------------------------------
-- 3) Server role membership (modern syntax)
--------------------------------------------------------------------------------
SELECT
    N'ALTER SERVER ROLE ' + CAST(QUOTENAME(rolep.name) AS nvarchar(4000)) COLLATE DATABASE_DEFAULT +
    N' ADD MEMBER ' + CAST(QUOTENAME(memb.name) AS nvarchar(4000)) COLLATE DATABASE_DEFAULT + N';' AS [-- ServerRoleMembers]
FROM sys.server_role_members AS srm
JOIN sys.server_principals AS rolep ON rolep.principal_id = srm.role_principal_id
JOIN sys.server_principals AS memb  ON memb.principal_id  = srm.member_principal_id
WHERE rolep.type = 'R'
  AND memb.type IN ('S','U','G')
  AND memb.name COLLATE DATABASE_DEFAULT NOT IN (N'sa')
  AND memb.name COLLATE DATABASE_DEFAULT NOT LIKE N'##MS_%##' ESCAPE N'\'
ORDER BY rolep.name, memb.name;

--------------------------------------------------------------------------------
-- 4) Server-level permissions (SERVER + ENDPOINT; WITH GRANT OPTION via state='W')
--------------------------------------------------------------------------------
SELECT
    CASE perm.class_desc
        WHEN 'SERVER' THEN
            (CASE perm.state WHEN 'G' THEN N'GRANT ' WHEN 'W' THEN N'GRANT ' WHEN 'D' THEN N'DENY ' WHEN 'R' THEN N'REVOKE ' END) +
            perm.permission_name + N' TO ' + CAST(QUOTENAME(prin.name) AS nvarchar(4000)) COLLATE DATABASE_DEFAULT +
            CASE WHEN perm.state = 'W' THEN N' WITH GRANT OPTION' ELSE N'' END + N';'
        WHEN 'ENDPOINT' THEN
            (CASE perm.state WHEN 'G' THEN N'GRANT ' WHEN 'W' THEN N'GRANT ' WHEN 'D' THEN N'DENY ' WHEN 'R' THEN N'REVOKE ' END) +
            perm.permission_name + N' ON ENDPOINT::' + CAST(QUOTENAME(ep.name) AS nvarchar(4000)) COLLATE DATABASE_DEFAULT +
            N' TO ' + CAST(QUOTENAME(prin.name) AS nvarchar(4000)) COLLATE DATABASE_DEFAULT +
            CASE WHEN perm.state = 'W' THEN N' WITH GRANT OPTION' ELSE N'' END + N';'
    END AS [-- ServerPermissions]
FROM sys.server_permissions AS perm
JOIN sys.server_principals  AS prin ON prin.principal_id = perm.grantee_principal_id
LEFT JOIN sys.endpoints     AS ep   ON ep.endpoint_id = perm.major_id
WHERE perm.class_desc IN ('SERVER','ENDPOINT')
  AND prin.type IN ('S','U','G')
  AND prin.name COLLATE DATABASE_DEFAULT NOT IN (N'sa')
  AND prin.name COLLATE DATABASE_DEFAULT NOT LIKE N'##MS_%##' ESCAPE N'\'
ORDER BY prin.name, perm.class_desc, perm.permission_name;
