USE AdventureWorks2022;
GO
CREATE OR ALTER PROC dba.usp_memory_grants
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        mg.request_id,
        mg.session_id,
        s.login_name,
        s.host_name,
        s.program_name,
        mg.grant_time,
        mg.request_time,
        mg.requested_memory_kb,
        mg.granted_memory_kb,
        mg.required_memory_kb,
        mg.used_memory_kb,
        mg.max_used_memory_kb,
        mg.queue_id,
        mg.wait_time_ms,
        mg.resource_semaphore_id,
        mg.is_next_candidate,
        mg.requested_memory_kb / 1024.0 AS requested_mb,
        mg.granted_memory_kb  / 1024.0 AS granted_mb,
        txt.text AS sql_text
    FROM sys.dm_exec_query_memory_grants AS mg
    LEFT JOIN sys.dm_exec_sessions AS s ON s.session_id = mg.session_id
    OUTER APPLY sys.dm_exec_sql_text(mg.sql_handle) AS txt
    ORDER BY mg.granted_memory_kb DESC, mg.request_time;
END;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'dmv_cert')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.crypt_properties WHERE major_id=OBJECT_ID(N'dba.usp_memory_grants'))
        DROP SIGNATURE FROM OBJECT::dba.usp_memory_grants BY CERTIFICATE dmv_cert;
    ADD SIGNATURE TO OBJECT::dba.usp_memory_grants BY CERTIFICATE dmv_cert;
END
GO
GRANT EXECUTE ON dba.usp_memory_grants TO [role_dmv_cert_readers];
GO
