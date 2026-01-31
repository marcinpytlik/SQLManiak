/* ============================================================================
   Soft guard + Audit
   - Allow ONLY AD groups matching: DOMENA\sql%
   - Exceptions allowed via whitelist table
   - Blocks: CREATE LOGIN (only)
   - Allows: DROP LOGIN, ALTER LOGIN (so you can clean up old logins)
   - Adds SQL Server Audit for:
       * SERVER_PRINCIPAL_CHANGE_GROUP (create/alter/drop logins)
       * SERVER_ROLE_MEMBER_CHANGE_GROUP (server role membership changes)
   Database: master
   ============================================================================ */

USE master;
GO

/* ---------------------------------------------------------------------------
   0) CONFIG: set audit file path (MUST exist, SQL Server service must write)
   --------------------------------------------------------------------------- */
DECLARE @AuditPath nvarchar(260) = N'D:\SQLAudit\';  -- <<< ZMIEŃ, jeśli trzeba
-- Przykład: N'E:\Audit\SQL\'
GO

/* ---------------------------------------------------------------------------
   1) Whitelist table (allowed principals)
   --------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.PermittedServerPrincipals', 'U') IS NULL
BEGIN
  CREATE TABLE dbo.PermittedServerPrincipals
  (
      PrincipalName sysname NOT NULL PRIMARY KEY,
      Reason        nvarchar(200) NULL,
      AddedAt       datetime2(0) NOT NULL CONSTRAINT DF_PSP_AddedAt DEFAULT (sysdatetime())
  );
END
GO

/* (Optional) Add exceptions here (ONLY if truly needed)
INSERT dbo.PermittedServerPrincipals(PrincipalName, Reason)
VALUES
  (N'DOMENA\svc_sqlagent', N'Konto serwisowe - wymagane'),
  (N'DOMENA\svc_vendor',   N'Wyjątek - wymagane przez aplikację');
GO
*/

/* ---------------------------------------------------------------------------
   2) Soft trigger (CREATE_LOGIN only)
   --------------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_OnlyAllowedLogins_Soft
ON ALL SERVER
FOR CREATE_LOGIN
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ev  xml     = EVENTDATA();
    DECLARE @obj sysname = @ev.value('(/EVENT_INSTANCE/ObjectName)[1]', 'sysname');

    -- Defensive: no object name -> block
    IF @obj IS NULL OR LTRIM(RTRIM(@obj)) = N''
    BEGIN
        RAISERROR(N'Blokada: CREATE LOGIN odrzucone (brak ObjectName w EVENTDATA).', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- Whitelist always allowed
    IF EXISTS (SELECT 1 FROM master.dbo.PermittedServerPrincipals WHERE PrincipalName = @obj)
        RETURN;

    -- Identify created principal type
    DECLARE @type_desc nvarchar(60) =
    (
        SELECT sp.type_desc
        FROM sys.server_principals sp
        WHERE sp.name = @obj
    );

    -- If type cannot be resolved, block
    IF @type_desc IS NULL
    BEGIN
        RAISERROR(N'Blokada: CREATE LOGIN odrzucone (nie rozpoznano typu principal). Login=%s', 16, 1, @obj);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- Main rule: ONLY WINDOWS_GROUP + name DOMENA\sql-haa%
    IF NOT (@type_desc = N'WINDOWS_GROUP' AND @obj LIKE N'DOMENA\sql%')
    BEGIN
        RAISERROR(
            N'Blokada: dozwolone są wyłącznie loginy typu Windows Group zgodne z DOMENA\sql%% (lub whitelist). Próba: %s (%s).',
            16, 1, @obj, @type_desc
        );
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

/* ---------------------------------------------------------------------------
   3) SQL Server Audit (logins + server role membership changes)
   --------------------------------------------------------------------------- */

DECLARE @AuditName sysname = N'Audit_ServerSecurity';
DECLARE @AuditSpec sysname = N'AuditSpec_ServerSecurity';

-- 3.1 Create audit if missing
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = @AuditName)
BEGIN
    DECLARE @sql nvarchar(max) =
N'CREATE SERVER AUDIT ' + QUOTENAME(@AuditName) + N'
TO FILE
(
    FILEPATH = ' + QUOTENAME(@AuditPath,'''') + N',
    MAXSIZE = 2048 MB,
    MAX_ROLLOVER_FILES = 20,
    RESERVE_DISK_SPACE = OFF
)
WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);';

    EXEC sys.sp_executesql @sql;
END;

-- 3.2 Enable audit
DECLARE @sql2 nvarchar(max) =
N'ALTER SERVER AUDIT ' + QUOTENAME(@AuditName) + N' WITH (STATE = ON);';
EXEC sys.sp_executesql @sql2;

-- 3.3 Create audit specification if missing
IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = @AuditSpec)
BEGIN
    DECLARE @sql3 nvarchar(max) =
N'CREATE SERVER AUDIT SPECIFICATION ' + QUOTENAME(@AuditSpec) + N'
FOR SERVER AUDIT ' + QUOTENAME(@AuditName) + N'
    ADD (SERVER_PRINCIPAL_CHANGE_GROUP),
    ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP)
WITH (STATE = ON);';

    EXEC sys.sp_executesql @sql3;
END
ELSE
BEGIN
    -- Ensure spec is ON
    DECLARE @sql4 nvarchar(max) =
N'ALTER SERVER AUDIT SPECIFICATION ' + QUOTENAME(@AuditSpec) + N' WITH (STATE = ON);';
    EXEC sys.sp_executesql @sql4;
END
GO

/* ---------------------------------------------------------------------------
   4) Status / quick checks
   --------------------------------------------------------------------------- */

-- Trigger status
SELECT
    t.name        AS TriggerName,
    t.is_disabled AS IsDisabled,
    t.create_date,
    t.modify_date
FROM sys.server_triggers t
WHERE t.name = N'trg_OnlyAllowedLogins_Soft';

-- Whitelist preview
SELECT TOP (200)
    PrincipalName, Reason, AddedAt
FROM master.dbo.PermittedServerPrincipals
ORDER BY AddedAt DESC;

-- Audit status
SELECT
    a.name,
    a.is_state_enabled,
    a.type_desc,
    a.create_date
FROM sys.server_audits a
WHERE a.name = N'Audit_ServerSecurity';

SELECT
    s.name,
    s.is_state_enabled,
    s.create_date
FROM sys.server_audit_specifications s
WHERE s.name = N'AuditSpec_ServerSecurity';
GO

/* ---------------------------------------------------------------------------
   5) Read audit files (EDIT path prefix if needed)
   --------------------------------------------------------------------------- */
-- UWAGA: fn_get_audit_file potrzebuje konkretnego prefixu ścieżki.
-- Zmień 'D:\SQLAudit\Audit_ServerSecurity*' na zgodny z @AuditPath, jeśli inny.

-- SELECT TOP (200)
--     event_time,
--     action_id,
--     succeeded,
--     server_principal_name,
--     database_name,
--     object_name,
--     statement
-- FROM sys.fn_get_audit_file(N'D:\SQLAudit\Audit_ServerSecurity*', DEFAULT, DEFAULT)
-- ORDER BY event_time DESC;
GO

/* ---------------------------------------------------------------------------
   6) Emergency controls (commented)
   --------------------------------------------------------------------------- */
-- DISABLE TRIGGER dbo.trg_OnlyAllowedLogins_Soft ON ALL SERVER;
-- ENABLE  TRIGGER dbo.trg_OnlyAllowedLogins_Soft ON ALL SERVER;
-- DROP TRIGGER dbo.trg_OnlyAllowedLogins_Soft ON ALL SERVER;

-- ALTER SERVER AUDIT SPECIFICATION [AuditSpec_ServerSecurity] WITH (STATE = OFF);
-- ALTER SERVER AUDIT [Audit_ServerSecurity] WITH (STATE = OFF);
-- DROP SERVER AUDIT SPECIFICATION [AuditSpec_ServerSecurity];
-- DROP SERVER AUDIT [Audit_ServerSecurity];
GO