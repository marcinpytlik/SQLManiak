/* BufferPool_ModifiedPages.sql
   Ile „brudnych” stron per baza? (wymaga VIEW SERVER STATE).
*/
SET NOCOUNT ON;

SELECT
    DB_NAME(database_id) AS DatabaseName,
    SUM(CASE WHEN is_modified = 1 THEN 1 ELSE 0 END) AS DirtyPages,
    COUNT(*) AS TotalPages,
    CAST(100.0 * SUM(CASE WHEN is_modified = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS DirtyPct
FROM sys.dm_os_buffer_descriptors
GROUP BY database_id
ORDER BY DirtyPages DESC;
