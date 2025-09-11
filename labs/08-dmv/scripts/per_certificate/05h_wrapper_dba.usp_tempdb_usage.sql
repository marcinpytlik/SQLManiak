USE AdventureWorks2022;
GO
CREATE OR ALTER PROC dba.usp_tempdb_usage
AS
BEGIN
    SET NOCOUNT ON;

    WITH ses AS (
        SELECT s.session_id, s.login_name, s.host_name, s.program_name, s.status
        FROM sys.dm_exec_sessions AS s
        WHERE s.is_user_process = 1
    ),
    sp AS (
        SELECT
            session_id,
            user_objects_alloc_page_count     - user_objects_dealloc_page_count     AS user_pages,
            internal_objects_alloc_page_count - internal_objects_dealloc_page_count AS internal_pages
        FROM sys.dm_db_session_space_usage
    ),
    req AS (
        SELECT r.session_id, r.blocking_session_id, r.status AS request_status
        FROM sys.dm_exec_requests AS r
    )
    SELECT
        ses.session_id,
        ses.login_name,
        ses.host_name,
        ses.program_name,
        ses.status,
        req.request_status,
        req.blocking_session_id,
        CAST((ISNULL(sp.user_pages,0) + ISNULL(sp.internal_pages,0)) * 8.0/1024 AS decimal(18,2)) AS tempdb_mb,
        CAST(ISNULL(sp.user_pages,0)     * 8.0/1024 AS decimal(18,2)) AS user_mb,
        CAST(ISNULL(sp.internal_pages,0) * 8.0/1024 AS decimal(18,2)) AS internal_mb
    FROM ses
    LEFT JOIN sp  ON sp.session_id  = ses.session_id
    LEFT JOIN req ON req.session_id = ses.session_id
    ORDER BY tempdb_mb DESC, user_mb DESC;
END;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'dmv_cert')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.crypt_properties WHERE major_id=OBJECT_ID(N'dba.usp_tempdb_usage'))
        DROP SIGNATURE FROM OBJECT::dba.usp_tempdb_usage BY CERTIFICATE dmv_cert;
    ADD SIGNATURE TO OBJECT::dba.usp_tempdb_usage BY CERTIFICATE dmv_cert;
END
GO
GRANT EXECUTE ON dba.usp_tempdb_usage TO [role_dmv_cert_readers];
GO
