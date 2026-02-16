/* ============================================================
   RAPORT AUDYTOWY: Kto ma db_owner (dla baz użytkownika)
   SQL Server 2012+ (działa na 2022)
   - Pokazuje członków db_owner w każdej bazie
   - Mapuje user -> login (jeśli da się) + typy i SID
   - Uwaga: członkostwo przez zagnieżdżone grupy AD
           nie będzie wprost widoczne bez zapytań do AD.
   ============================================================ */

SET NOCOUNT ON;

DECLARE @OnlyThisDb sysname = NULL;  -- np. N'AdventureWorks2022' albo NULL = wszystkie

IF OBJECT_ID('tempdb..#DbOwnerReport') IS NOT NULL DROP TABLE #DbOwnerReport;
CREATE TABLE #DbOwnerReport
(
    ServerName           sysname        NOT NULL,
    DatabaseName         sysname        NOT NULL,
    DbOwnerMember        sysname        NOT NULL, -- nazwa USER-a w bazie (np. DOMAIN\Group)
    MemberTypeDesc       nvarchar(60)   NULL,     -- typ principal w bazie
    IsFixedRoleMember    bit            NOT NULL,
    LoginNameMapped      sysname        NULL,     -- login na serwerze (jeśli zmapowany)
    LoginTypeDesc        nvarchar(60)   NULL,
    IsADGroup            bit            NULL,
    CreateDate           datetime       NULL,
    ModifyDate           datetime       NULL,
    DbPrincipalSid       varbinary(85)  NULL,
    ServerPrincipalSid   varbinary(85)  NULL
);

DECLARE @sql nvarchar(max) = N'';

;WITH dbs AS
(
    SELECT d.name
    FROM sys.databases AS d
    WHERE d.state_desc = N'ONLINE'
      AND d.database_id > 4          -- pomiń systemowe
      AND d.is_distributor = 0
      AND (@OnlyThisDb IS NULL OR d.name = @OnlyThisDb)
)
SELECT @sql = @sql + N'
USE ' + QUOTENAME(name) + N';
INSERT INTO #DbOwnerReport
(
    ServerName, DatabaseName, DbOwnerMember, MemberTypeDesc, IsFixedRoleMember,
    LoginNameMapped, LoginTypeDesc, IsADGroup, CreateDate, ModifyDate,
    DbPrincipalSid, ServerPrincipalSid
)
SELECT
    @@SERVERNAME AS ServerName,
    DB_NAME()    AS DatabaseName,
    m.name       AS DbOwnerMember,
    m.type_desc  AS MemberTypeDesc,
    CAST(1 AS bit) AS IsFixedRoleMember,
    sp.name      AS LoginNameMapped,
    sp.type_desc AS LoginTypeDesc,
    CASE WHEN sp.type_desc = ''WINDOWS_GROUP'' THEN CAST(1 AS bit)
         WHEN m.type_desc  = ''WINDOWS_GROUP'' THEN CAST(1 AS bit)
         ELSE CAST(0 AS bit) END AS IsADGroup,
    m.create_date,
    m.modify_date,
    m.sid        AS DbPrincipalSid,
    sp.sid       AS ServerPrincipalSid
FROM sys.database_role_members drm
JOIN sys.database_principals r
    ON r.principal_id = drm.role_principal_id
JOIN sys.database_principals m
    ON m.principal_id = drm.member_principal_id
LEFT JOIN sys.server_principals sp
    ON sp.sid = m.sid
WHERE r.name = ''db_owner''
  AND m.type IN (''S'',''U'',''G'')   -- SQL user, Windows user, Windows group
  AND m.name NOT IN (''dbo'')         -- zwykle nie raportujemy dbo jako "konto"
;'
FROM dbs;

EXEC sp_executesql @sql, N'@OnlyThisDb sysname', @OnlyThisDb=@OnlyThisDb;

/* Wynik końcowy */
SELECT
    ServerName,
    DatabaseName,
    DbOwnerMember,
    MemberTypeDesc,
    LoginNameMapped,
    LoginTypeDesc,
    IsADGroup,
    CreateDate,
    ModifyDate
FROM #DbOwnerReport
ORDER BY DatabaseName, DbOwnerMember;
