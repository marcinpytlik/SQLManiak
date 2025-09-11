USE AdventureWorks2022;
GO
CREATE OR ALTER PROC dba.usp_plan_cache
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        qs.query_hash,
        qs.query_plan_hash,
        qs.plan_handle,
        qs.sql_handle,
        qs.execution_count,
        qs.total_worker_time,        -- µs
        qs.total_elapsed_time,       -- µs
        qs.total_logical_reads,
        qs.total_logical_writes,
        qs.total_physical_reads,
        qs.max_worker_time,
        qs.max_elapsed_time,
        qs.max_logical_reads,
        qs.max_logical_writes,
        CONVERT(decimal(18,2), qs.total_worker_time   / NULLIF(qs.execution_count,0)) AS avg_worker_time,
        CONVERT(decimal(18,2), qs.total_elapsed_time  / NULLIF(qs.execution_count,0)) AS avg_elapsed_time,
        CONVERT(decimal(18,2), qs.total_logical_reads / NULLIF(qs.execution_count,0)) AS avg_logical_reads,
        CONVERT(decimal(18,2), qs.total_logical_writes/ NULLIF(qs.execution_count,0)) AS avg_logical_writes,
        DB_NAME(qt.dbid) AS dbname,
        SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
            CASE WHEN qs.statement_end_offset = -1
                 THEN (LEN(CONVERT(nvarchar(max), qt.text)) - qs.statement_start_offset/2) + 1
                 ELSE (qs.statement_end_offset - qs.statement_start_offset)/2 + 1 END) AS sql_text
    FROM sys.dm_exec_query_stats AS qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt;
END;
GO
/* 2) Podpis procedury certyfikatem (po każdej zmianie — podpisać ponownie) */
IF EXISTS (
  SELECT 1
  FROM sys.crypt_properties
  WHERE class_desc = 'OBJECT_OR_COLUMN'
    AND major_id   = OBJECT_ID(N'dba.usp_plan_cache')
)
BEGIN
  DROP SIGNATURE FROM OBJECT::dba.usp_plan_cache BY CERTIFICATE dmv_cert;
END;
ADD  SIGNATURE TO   OBJECT::dba.usp_plan_cache BY CERTIFICATE dmv_cert;
GO

/* 3) Uprawnienie dla czytelników (rola „cert”) */
GRANT EXECUTE ON dba.usp_plan_cache TO [role_dmv_cert_readers];
GO