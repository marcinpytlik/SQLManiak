
USE AuditDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dbo')
    EXEC('CREATE SCHEMA dbo');
GO

IF OBJECT_ID('dbo.AuditEvents','U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditEvents
    (
        AuditEventId     bigint IDENTITY(1,1) PRIMARY KEY,
        event_time       datetime2(3) NOT NULL,
        event_name       sysname      NOT NULL,
        action_id        nvarchar(10) NULL,
        succeeded        bit          NULL,
        server_principal_name   sysname NULL,
        session_server_principal_name sysname NULL,
        database_principal_name sysname NULL,
        database_name    sysname NULL,
        schema_name      sysname NULL,
        object_name      sysname NULL,
        statement        nvarchar(max) NULL,
        host_name        sysname NULL,
        application_name sysname NULL,
        file_name        nvarchar(4000) NULL,
        file_offset      bigint NULL,
        src_hash         binary(16) NULL  -- deduplikacja
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditEvents_event_time' AND object_id = OBJECT_ID('dbo.AuditEvents'))
    CREATE INDEX IX_AuditEvents_event_time ON dbo.AuditEvents(event_time DESC);
GO

IF OBJECT_ID('dbo.v_Audit_PermissionChanges','V') IS NOT NULL
    DROP VIEW dbo.v_Audit_PermissionChanges;
GO

CREATE VIEW dbo.v_Audit_PermissionChanges AS
SELECT *
FROM dbo.AuditEvents
WHERE event_name LIKE '%PERMISSION_CHANGE%'
   OR event_name LIKE '%ROLE_MEMBER_CHANGE%';
GO

/* Procedura importu z plików audytu z deduplikacją */
IF OBJECT_ID('dbo.usp_ImportAuditFromFiles','P') IS NOT NULL
    DROP PROCEDURE dbo.usp_ImportAuditFromFiles;
GO

CREATE PROCEDURE dbo.usp_ImportAuditFromFiles
    @FilePattern nvarchar(4000)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @t TABLE
    (
        event_time       datetime2(3),
        event_name       nvarchar(256),
        action_id        nvarchar(10),
        succeeded        bit,
        server_principal_name   sysname,
        session_server_principal_name sysname,
        database_principal_name sysname,
        database_name    sysname,
        schema_name      sysname,
        object_name      sysname,
        statement        nvarchar(max),
        host_name        sysname,
        application_name sysname,
        file_name        nvarchar(4000),
        file_offset      bigint
    );

    INSERT INTO @t
    SELECT
        event_time,
        event_name,
        action_id,
        succeeded,
        server_principal_name,
        session_server_principal_name,
        database_principal_name,
        database_name,
        schema_name,
        object_name,
        statement,
        host_name,
        application_name,
        file_name,
        file_offset
    FROM sys.fn_get_audit_file(@FilePattern, DEFAULT, DEFAULT);

    /* Deduplikacja: hash po (file_name, file_offset) + event_time + event_name + principal */
    WITH src AS (
        SELECT t.*,
               CONVERT(binary(16), HASHBYTES('MD5',
                   CONCAT_WS('|',
                       COALESCE(t.file_name,''),
                       COALESCE(CONVERT(varchar(32), t.file_offset),''),
                       COALESCE(CONVERT(varchar(33), t.event_time, 126),''),
                       COALESCE(t.event_name,''),
                       COALESCE(t.session_server_principal_name,''),
                       COALESCE(t.database_principal_name,''),
                       COALESCE(t.database_name,''),
                       COALESCE(t.object_name,'')
                   )
               )) AS src_hash
        FROM @t AS t
    )
    INSERT INTO dbo.AuditEvents
    (
        event_time, event_name, action_id, succeeded,
        server_principal_name, session_server_principal_name,
        database_principal_name, database_name, schema_name, object_name,
        statement, host_name, application_name, file_name, file_offset, src_hash
    )
    SELECT s.event_time, s.event_name, s.action_id, s.succeeded,
           s.server_principal_name, s.session_server_principal_name,
           s.database_principal_name, s.database_name, s.schema_name, s.object_name,
           s.statement, s.host_name, s.application_name, s.file_name, s.file_offset, s.src_hash
    FROM src AS s
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.AuditEvents AS a
        WHERE a.src_hash = s.src_hash
    );
END
GO
