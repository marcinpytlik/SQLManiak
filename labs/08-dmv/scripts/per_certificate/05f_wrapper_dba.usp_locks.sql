USE AdventureWorks2022;
GO

/* 1) Procedura */
CREATE OR ALTER PROC dba.usp_locks
AS
BEGIN
    SET NOCOUNT ON;

    WITH base AS (
        SELECT
            tl.request_session_id                  AS session_id,
            tl.resource_type,
            tl.resource_database_id,
            DB_NAME(tl.resource_database_id)       AS dbname,
            tl.resource_associated_entity_id       AS entity_id,
            tl.request_mode,
            tl.request_status,
            tl.request_owner_type,
            tl.resource_description,
            s.login_name,
            s.host_name,
            s.program_name,
            o.name                                  AS object_name,
            sch.name                                AS schema_name,
            p.index_id
        FROM sys.dm_tran_locks AS tl
        LEFT JOIN sys.dm_exec_sessions AS s
               ON s.session_id = tl.request_session_id
        LEFT JOIN sys.partitions AS p
               ON p.hobt_id = CASE
                                WHEN tl.resource_type IN ('KEY','PAGE','RID')
                                  THEN tl.resource_associated_entity_id
                                ELSE NULL
                              END
        LEFT JOIN sys.objects AS o
               ON o.object_id = CASE
                                   WHEN tl.resource_type = 'OBJECT'
                                     THEN tl.resource_associated_entity_id
                                   WHEN tl.resource_type IN ('KEY','PAGE','RID')
                                     THEN p.object_id
                                   ELSE NULL
                               END
        LEFT JOIN sys.schemas AS sch
               ON sch.schema_id = o.schema_id
    )
    SELECT
        b.session_id,
        b.login_name,
        b.host_name,
        b.program_name,
        b.resource_type,
        b.resource_database_id,
        b.dbname,
        b.entity_id,
        b.request_mode,
        b.request_status,
        b.request_owner_type,
        b.resource_description,
        b.object_name,
        b.schema_name,
        b.index_id,
        COALESCE(txt_cur.text, txt_last.text)      AS most_recent_sql_text
    FROM base AS b
    -- 1) jeśli sesja ma aktualny request, użyj jego sql_handle
    OUTER APPLY (
        SELECT r.sql_handle
        FROM sys.dm_exec_requests AS r
        WHERE r.session_id = b.session_id
    ) AS cur
    OUTER APPLY sys.dm_exec_sql_text(cur.sql_handle) AS txt_cur
    -- 2) w przeciwnym razie: ostatni batch z połączenia
    LEFT  JOIN sys.dm_exec_connections AS c
           ON c.session_id = b.session_id
    OUTER APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) AS txt_last;
END;
GO

/* 2) Podpis certyfikatem (odśwież po każdej zmianie definicji) */
IF EXISTS (
    SELECT 1
    FROM sys.crypt_properties
    WHERE class_desc = 'OBJECT_OR_COLUMN'
      AND major_id   = OBJECT_ID(N'dba.usp_locks')
)
    DROP SIGNATURE FROM OBJECT::dba.usp_locks BY CERTIFICATE dmv_cert;

ADD SIGNATURE TO OBJECT::dba.usp_locks BY CERTIFICATE dmv_cert;
GO

/* 3) Uprawnienie dla roli „cert” */
/* 3) Uprawnienie dla roli „cert” */
GRANT EXECUTE ON dba.usp_locks TO [role_dmv_cert_readers];
GO
