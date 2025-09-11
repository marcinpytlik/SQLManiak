USE AdventureWorks2022;
GO
CREATE OR ALTER PROC dba.usp_index_unused
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH u AS (
        SELECT *
        FROM sys.dm_db_index_usage_stats
        WHERE database_id = DB_ID()
    ),
    p AS (
        SELECT object_id, index_id, SUM(rows) AS rows_count
        FROM sys.partitions
        WHERE index_id > 0
        GROUP BY object_id, index_id
    )
    SELECT
        SCHEMA_NAME(o.schema_id) AS schema_name,
        o.name                   AS table_name,
        i.name                   AS index_name,
        i.index_id,
        p.rows_count,
        u.user_seeks, u.user_scans, u.user_lookups, u.user_updates,
        u.last_user_seek, u.last_user_scan, u.last_user_lookup, u.last_user_update
    FROM sys.indexes AS i
    JOIN sys.objects AS o ON o.object_id = i.object_id
    LEFT JOIN u ON u.object_id = i.object_id AND u.index_id = i.index_id
    LEFT JOIN p ON p.object_id = i.object_id AND p.index_id = i.index_id
    WHERE o.type = 'U'
      AND i.index_id > 1                     -- pomiń heap/PK
      AND i.is_hypothetical = 0
      AND i.is_primary_key = 0
      AND i.is_unique_constraint = 0
      AND COALESCE(u.user_seeks,0) = 0
      AND COALESCE(u.user_scans,0) = 0
      AND COALESCE(u.user_lookups,0) = 0
    ORDER BY p.rows_count DESC;
END;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'dmv_cert')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.crypt_properties WHERE major_id=OBJECT_ID(N'dba.usp_index_unused'))
        DROP SIGNATURE FROM OBJECT::dba.usp_index_unused BY CERTIFICATE dmv_cert;
    ADD SIGNATURE TO OBJECT::dba.usp_index_unused BY CERTIFICATE dmv_cert;
END
GO
GRANT EXECUTE ON dba.usp_index_unused TO [role_dmv_cert_readers];
GO
