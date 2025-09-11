USE AdventureWorks2022;
GO
CREATE OR ALTER PROC dba.usp_qstore_top_duration
    @days int = 7,
    @top  int = 20
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @from datetime2 = DATEADD(DAY, -@days, SYSUTCDATETIME());

    SELECT TOP (@top)
        DB_NAME()                               AS dbname,
        qsq.query_id,
        MAX(qsp.plan_id)                        AS sample_plan_id,
        SUM(rs.count_executions)                AS execs,
        SUM(rs.count_executions * rs.avg_duration) / NULLIF(SUM(rs.count_executions),0) / 1000.0 AS avg_duration_ms,
        SUM(rs.count_executions * rs.avg_cpu_time) / NULLIF(SUM(rs.count_executions),0) / 1000.0  AS avg_cpu_ms,
        SUM(rs.count_executions * rs.avg_logical_io_reads) / NULLIF(SUM(rs.count_executions),0)  AS avg_reads,
        SUBSTRING(qst.query_sql_text,1,4000)    AS sql_text
    FROM sys.query_store_query_text     AS qst
    JOIN sys.query_store_query          AS qsq ON qsq.query_text_id = qst.query_text_id
    JOIN sys.query_store_plan           AS qsp ON qsp.query_id      = qsq.query_id
    JOIN sys.query_store_runtime_stats  AS rs  ON rs.plan_id        = qsp.plan_id
    JOIN sys.query_store_runtime_stats_interval AS rsi ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
    WHERE rsi.start_time >= @from
      AND rs.execution_type = 0   -- regular
    GROUP BY qsq.query_id, qst.query_sql_text
    ORDER BY avg_duration_ms DESC, execs DESC;
END;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'dmv_cert')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.crypt_properties WHERE major_id=OBJECT_ID(N'dba.usp_qstore_top_duration'))
        DROP SIGNATURE FROM OBJECT::dba.usp_qstore_top_duration BY CERTIFICATE dmv_cert;
    ADD SIGNATURE TO OBJECT::dba.usp_qstore_top_duration BY CERTIFICATE dmv_cert;
END
GO
GRANT EXECUTE ON dba.usp_qstore_top_duration TO [role_dmv_cert_readers];
GO
