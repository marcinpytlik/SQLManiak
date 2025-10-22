SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.ufn_AuditEvents','IF') IS NOT NULL
    DROP FUNCTION dbo.ufn_AuditEvents;
GO

CREATE FUNCTION dbo.ufn_AuditEvents
(
    @AuditName sysname, 
    @FromDate  datetime2(7) = NULL, 
    @ToDate    datetime2(7) = NULL
)
RETURNS @t TABLE
(
    event_time_utc     datetime2(7)   NOT NULL,
    event_time_local   datetime2(7)   NOT NULL,
    action_id          nvarchar(4)    NOT NULL,
    operation          varchar(16)    NOT NULL,
    succeeded          bit            NULL,
    principal          nvarchar(256)  NULL,
    server_principal_name         nvarchar(256) NULL,
    session_server_principal_name  nvarchar(256) NULL,
    database_principal_name        nvarchar(256) NULL,
    server_instance_name           nvarchar(256) NULL,
    database_name      sysname       NULL,
    schema_name        sysname       NULL,
    object_name        sysname       NULL,
    obj3               nvarchar(776)  NULL,
    statement          nvarchar(max)  NULL,
    application_name   nvarchar(128)  NULL, -- 2016: brak w fn_get_audit_file -> NULL
    client_hostname    nvarchar(128)  NULL, -- 2016: brak w fn_get_audit_file -> NULL
    session_id         int            NULL
)
AS
BEGIN
    DECLARE @FilePath nvarchar(4000);

    -- 1) Aktywny audyt → ścieżka z DM
    SELECT TOP (1) @FilePath = s.audit_file_path
    FROM sys.dm_server_audit_status AS s
    WHERE s.name = @AuditName
    ORDER BY CASE WHEN s.status_desc = 'STARTED' THEN 0 ELSE 1 END,
             s.status_time DESC;

    -- 2) Jeśli brak → z definicji audytu
    IF @FilePath IS NULL
    BEGIN
        SELECT TOP (1) @FilePath = fa.log_file_path
        FROM sys.server_audits AS a
        LEFT JOIN sys.server_file_audits AS fa
            ON fa.audit_id = a.audit_id
        WHERE a.name = @AuditName
        ORDER BY a.audit_id;
    END

    IF @FilePath IS NULL
        RETURN;

    -- 3) Wildcard na pliki audytu
    IF RIGHT(@FilePath,1) NOT IN ('\','/')
       AND RIGHT(LOWER(@FilePath), 9) <> '.sqlaudit'
       SET @FilePath = @FilePath + N'\*.sqlaudit';
    ELSE IF RIGHT(LOWER(@FilePath), 9) <> '.sqlaudit'
       SET @FilePath = @FilePath + N'*.sqlaudit';

    DECLARE @utc_from datetime2(7) = @FromDate;
    DECLARE @utc_to   datetime2(7) = @ToDate;

    -- 4) Wczytaj wpisy z plików (2016: bez app/host)
    INSERT INTO @t
    (
        event_time_utc, event_time_local, action_id, operation, succeeded,
        principal, server_principal_name, session_server_principal_name, database_principal_name,
        server_instance_name, database_name, schema_name, object_name, obj3,
        statement, application_name, client_hostname, session_id
    )
    SELECT
        x.event_time AS event_time_utc,
        SWITCHOFFSET(x.event_time, DATEPART(TZOFFSET, SYSDATETIMEOFFSET())) AS event_time_local,
        x.action_id,
        CASE x.action_id WHEN N'SL' THEN 'SELECT'
                         WHEN N'IN' THEN 'INSERT'
                         WHEN N'UP' THEN 'UPDATE'
                         WHEN N'DL' THEN 'DELETE'
                         WHEN N'EX' THEN 'EXECUTE'
                         WHEN N'RF' THEN 'REFERENCES'
                         ELSE CONVERT(varchar(16), x.action_id) END AS operation,
        x.succeeded,
        COALESCE(x.database_principal_name, x.session_server_principal_name) AS principal,
        x.server_principal_name,
        x.session_server_principal_name,
        x.database_principal_name,
        x.server_instance_name,
        x.database_name,
        x.schema_name,
        x.object_name,
        CASE 
          WHEN x.database_name IS NOT NULL AND x.schema_name IS NOT NULL AND x.object_name IS NOT NULL
          THEN QUOTENAME(x.database_name) + N'.' + QUOTENAME(x.schema_name) + N'.' + QUOTENAME(x.object_name)
          ELSE NULL
        END AS obj3,
        x.statement,
        NULL AS application_name,      -- 2016: brak kolumny
        NULL AS client_hostname,       -- 2016: brak kolumny
        x.session_id
    FROM sys.fn_get_audit_file(@FilePath, DEFAULT, DEFAULT) AS x
    WHERE (@utc_from IS NULL OR x.event_time >= @utc_from)
      AND (@utc_to   IS NULL OR x.event_time <  @utc_to)
      AND x.action_id IN (N'SL',N'IN',N'UP',N'DL',N'EX',N'RF');

    RETURN;
END
GO
