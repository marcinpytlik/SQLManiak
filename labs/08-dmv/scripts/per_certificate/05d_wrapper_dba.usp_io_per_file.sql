USE AdventureWorks2022;
GO
/* 1) Procedura */
CREATE OR ALTER PROC dba.usp_io_per_file
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        DB_NAME(vfs.database_id)     AS dbname,
        vfs.database_id,
        vfs.file_id,
        mf.type_desc                 AS file_type,
        mf.name                      AS file_name,
        vfs.num_of_reads,
        vfs.num_of_writes,
        vfs.num_of_bytes_read        AS bytes_read,
        vfs.num_of_bytes_written     AS bytes_written,
        vfs.io_stall_read_ms,
        vfs.io_stall_write_ms,
        vfs.io_stall,                -- łączny stall (jeśli dostępny w Twojej wersji)
        vfs.size_on_disk_bytes,      -- rozmiar na dysku (jeśli dostępny)
        vfs.sample_ms
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
    JOIN sys.master_files AS mf
      ON mf.database_id = vfs.database_id
     AND mf.file_id     = vfs.file_id;
END;
GO

/* 2) Podpis procedury certyfikatem (po każdej zmianie — podpisać ponownie) */
IF EXISTS (
  SELECT 1
  FROM sys.crypt_properties
  WHERE class_desc = 'OBJECT_OR_COLUMN'
    AND major_id   = OBJECT_ID(N'dba.usp_io_per_file')
)
BEGIN
  DROP SIGNATURE FROM OBJECT::dba.usp_io_per_file BY CERTIFICATE dmv_cert;
END;
ADD  SIGNATURE TO   OBJECT::dba.usp_io_per_file BY CERTIFICATE dmv_cert;
GO

/* 3) Uprawnienie dla czytelników (rola „cert”) */
GRANT EXECUTE ON dba.usp_io_per_file TO [role_dmv_cert_readers];
GO