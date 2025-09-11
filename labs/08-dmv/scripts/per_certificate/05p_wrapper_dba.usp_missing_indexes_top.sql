USE AdventureWorks2022;
GO
CREATE OR ALTER PROC dba.usp_missing_indexes_top
    @top int = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@top)
        DB_NAME(mid.database_id) AS dbname,
        OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id) AS schema_name,
        OBJECT_NAME(mid.object_id, mid.database_id)        AS table_name,
        migs.user_seeks, migs.user_scans,
        CAST(migs.avg_total_user_cost * (migs.avg_user_impact/100.0) * (migs.user_seeks + migs.user_scans) AS decimal(18,2)) AS improvement_measure,
        mid.equality_columns,
        mid.inequality_columns,
        mid.included_columns
    FROM sys.dm_db_missing_index_group_stats AS migs
    JOIN sys.dm_db_missing_index_groups      AS mig  ON migs.group_handle  = mig.index_group_handle
    JOIN sys.dm_db_missing_index_details     AS mid  ON mig.index_handle   = mid.index_handle
    WHERE mid.database_id = DB_ID()
    ORDER BY improvement_measure DESC;
END;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'dmv_cert')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.crypt_properties WHERE major_id=OBJECT_ID(N'dba.usp_missing_indexes_top'))
        DROP SIGNATURE FROM OBJECT::dba.usp_missing_indexes_top BY CERTIFICATE dmv_cert;
    ADD SIGNATURE TO OBJECT::dba.usp_missing_indexes_top BY CERTIFICATE dmv_cert;
END
GO
GRANT EXECUTE ON dba.usp_missing_indexes_top TO [role_dmv_cert_readers];
GO
