USE AdventureWorks2022;
GO
CREATE OR ALTER PROC dba.usp_memory_clerks
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (50)
        mc.type                              AS clerk_type,
        SUM(mc.pages_kb)                     AS pages_kb,
        SUM(mc.virtual_memory_committed_kb)  AS vm_committed_kb,
        SUM(mc.awe_allocated_kb)             AS awe_kb,
        SUM(mc.shared_memory_committed_kb)   AS shared_committed_kb
    FROM sys.dm_os_memory_clerks AS mc
    GROUP BY mc.type
    ORDER BY pages_kb DESC;
END;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'dmv_cert')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.crypt_properties WHERE major_id=OBJECT_ID(N'dba.usp_memory_clerks'))
        DROP SIGNATURE FROM OBJECT::dba.usp_memory_clerks BY CERTIFICATE dmv_cert;
    ADD SIGNATURE TO OBJECT::dba.usp_memory_clerks BY CERTIFICATE dmv_cert;
END
GO
GRANT EXECUTE ON dba.usp_memory_clerks TO [role_dmv_cert_readers];
GO
