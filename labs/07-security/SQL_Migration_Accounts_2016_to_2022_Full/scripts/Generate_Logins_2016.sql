/* Generate_Logins_2016.sql — SQL 2016 -> script for SQL 2022
   - SQL Logins (hash + SID)
   - Windows Logins/Groups (SID)
   - Status (DISABLE)
   - Default DB / Language / Policy
   - Server role memberships
   - Server-level permissions
*/
SET NOCOUNT ON;
;WITH Src AS (
    SELECT sp.principal_id, sp.sid, sp.name, sp.type, sp.type_desc, sp.is_disabled,
           sl.password_hash, sl.is_policy_checked, sl.is_expiration_checked,
           sp.default_database_name, sp.default_language_name
    FROM sys.server_principals AS sp
    LEFT JOIN sys.sql_logins AS sl ON sl.principal_id = sp.principal_id
    WHERE sp.type IN ('S','U','G')
      AND sp.name NOT IN ('sa')
      AND sp.name NOT LIKE '##MS_%##' ESCAPE '\'
      AND sp.name NOT LIKE 'NT SERVICE\%'
      AND sp.name NOT LIKE 'NT AUTHORITY\%'
)
-- 1) CREATE LOGIN
SELECT
    CASE s.type
        WHEN 'S' THEN
            N'CREATE LOGIN ' + QUOTENAME(s.name) + N' WITH ' +
            N'PASSWORD = ' + CASE WHEN s.password_hash IS NOT NULL
                                  THEN N'0x' + CONVERT(nvarchar(256), s.password_hash, 2) + N' HASHED'
                                  ELSE N'''<<SET_PASSWORD_AFTER_MIGRATION>>'''
                             END + N', ' +
            N'SID = 0x' + CONVERT(nvarchar(256), s.sid, 2) + N', ' +
            N'DEFAULT_DATABASE = ' + QUOTENAME(COALESCE(NULLIF(s.default_database_name,''),'master')) + N', ' +
            N'DEFAULT_LANGUAGE = ' + QUOTENAME(COALESCE(NULLIF(s.default_language_name,''),'us_english')) + N', ' +
            N'CHECK_POLICY = ' + CASE WHEN s.is_policy_checked = 1 THEN 'ON' ELSE 'OFF' END + N', ' +
            N'CHECK_EXPIRATION = ' + CASE WHEN s.is_expiration_checked = 1 THEN 'ON' ELSE 'OFF' END + N';'
        WHEN 'U' THEN
            N'CREATE LOGIN ' + QUOTENAME(s.name) + N' FROM WINDOWS WITH ' +
            N'SID = 0x' + CONVERT(nvarchar(256), s.sid, 2) + N', ' +
            N'DEFAULT_DATABASE = ' + QUOTENAME(COALESCE(NULLIF(s.default_database_name,''),'master')) + N', ' +
            N'DEFAULT_LANGUAGE = ' + QUOTENAME(COALESCE(NULLIF(s.default_language_name,''),'us_english')) + N';'
        WHEN 'G' THEN
            N'CREATE LOGIN ' + QUOTENAME(s.name) + N' FROM WINDOWS WITH ' +
            N'SID = 0x' + CONVERT(nvarchar(256), s.sid, 2) + N';'
    END AS [-- CreateLogins]
FROM Src AS s
ORDER BY s.type, s.name;

-- 2) DISABLE
SELECT
    N'ALTER LOGIN ' + QUOTENAME(s.name) + N' DISABLE;' AS [-- DisabledLogins]
FROM Src AS s
WHERE s.is_disabled = 1
ORDER BY s.name;

-- 3) Server role membership
SELECT
    N'EXEC sp_addsrvrolemember @loginame = N' + QUOTENAME(memb.name,'''') +
    N', @rolename = N' + QUOTENAME(rolep.name,'''') + N';' AS [-- ServerRoleMembers]
FROM sys.server_role_members AS srm
JOIN sys.server_principals AS rolep ON rolep.principal_id = srm.role_principal_id
JOIN sys.server_principals AS memb  ON memb.principal_id  = srm.member_principal_id
WHERE rolep.type = 'R'
  AND memb.type IN ('S','U','G')
  AND memb.name NOT IN ('sa')
  AND memb.name NOT LIKE '##MS_%##' ESCAPE '\'
ORDER BY rolep.name, memb.name;

-- 4) Server-level permissions
SELECT
    CASE perm.state
        WHEN 'G' THEN N'GRANT '
        WHEN 'D' THEN N'DENY '
        WHEN 'R' THEN N'REVOKE '
    END +
    perm.permission_name + N' TO ' + QUOTENAME(prin.name) +
    CASE WHEN perm.state <> 'R' AND perm.with_grant_option = 1 THEN N' WITH GRANT OPTION' ELSE N'' END +
    N';' AS [-- ServerPermissions]
FROM sys.server_permissions AS perm
JOIN sys.server_principals  AS prin ON prin.principal_id = perm.grantee_principal_id
WHERE prin.type IN ('S','U','G')
  AND prin.name NOT IN ('sa')
  AND prin.name NOT LIKE '##MS_%##' ESCAPE '\'
ORDER BY prin.name, perm.permission_name;
