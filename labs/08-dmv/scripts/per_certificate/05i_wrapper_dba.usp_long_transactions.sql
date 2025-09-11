USE AdventureWorks2022;
GO
CREATE OR ALTER PROC dba.usp_long_transactions
    @min_seconds int = 30
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.session_id,
        s.login_name,
        s.host_name,
        s.program_name,
        DB_NAME(dt.database_id)                        AS dbname,
        t.transaction_id,
        t.transaction_begin_time,
        DATEDIFF(SECOND, t.transaction_begin_time, SYSDATETIME()) AS duration_sec,
        dt.database_transaction_log_bytes_used         AS log_bytes_used,
        dt.database_transaction_log_bytes_reserved     AS log_bytes_reserved,
        r.blocking_session_id,
        r.status                                       AS request_status
    FROM sys.dm_tran_session_transactions AS st
    JOIN sys.dm_tran_active_transactions   AS t  ON t.transaction_id = st.transaction_id
    LEFT JOIN sys.dm_tran_database_transactions AS dt ON dt.transaction_id = t.transaction_id
    LEFT JOIN sys.dm_exec_sessions         AS s  ON s.session_id = st.session_id
    LEFT JOIN sys.dm_exec_requests         AS r  ON r.session_id = st.session_id
    WHERE DATEDIFF(SECOND, t.transaction_begin_time, SYSDATETIME()) >= @min_seconds
    ORDER BY duration_sec DESC, log_bytes_reserved DESC;
END;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'dmv_cert')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.crypt_properties WHERE major_id=OBJECT_ID(N'dba.usp_long_transactions'))
        DROP SIGNATURE FROM OBJECT::dba.usp_long_transactions BY CERTIFICATE dmv_cert;
    ADD SIGNATURE TO OBJECT::dba.usp_long_transactions BY CERTIFICATE dmv_cert;
END
GO
GRANT EXECUTE ON dba.usp_long_transactions TO [role_dmv_cert_readers];
GO
