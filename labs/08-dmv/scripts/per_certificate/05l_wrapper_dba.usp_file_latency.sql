USE AdventureWorks2022;
GO
CREATE OR ALTER PROC dba.usp_file_latency
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        DB_NAME(vfs.database_id)                        AS dbname,
        vfs.database_id,
        vfs.file_id,
        mf.type_desc                                    AS file_type,
        mf.name                                         AS file_name,
        vfs.num_of_reads,
        vfs.io_stall_read_ms,
        CAST(1.0 * vfs.io_stall_read_ms / NULLIF(vfs.num_of_reads, 0) AS decimal(18,2))  AS read_latency_ms,
        vfs.num_of_writes,
        vfs.io_stall_write_ms,
        CAST(1.0 * vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes, 0) AS decimal(18,2)) AS write_latency_ms,
        vfs.num_of_bytes_read        / 1048576.0         AS read_mb,
        vfs.num_of_bytes_written     / 1048576.0         AS written_mb
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
    JOIN sys.master_files AS mf
      ON mf.database_id = vfs.database_id
     AND mf.file_id     = vfs.file_id
    ORDER BY (vfs.io_stall_read_ms + vfs.io_stall_write_ms) DESC;
END;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'dmv_cert')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.crypt_properties WHERE major_id=OBJECT_ID(N'dba.usp_file_latency'))
        DROP SIGNATURE FROM OBJECT::dba.usp_file_latency BY CERTIFICATE dmv_cert;
    ADD SIGNATURE TO OBJECT::dba.usp_file_latency BY CERTIFICATE dmv_cert;
END
GO
GRANT EXECUTE ON dba.usp_file_latency TO [role_dmv_cert_readers];
GO
