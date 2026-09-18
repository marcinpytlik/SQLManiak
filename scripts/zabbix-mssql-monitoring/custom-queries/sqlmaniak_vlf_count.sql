SET NOCOUNT ON;

SELECT
    s.name AS db,
    COUNT_BIG(*) AS vlf_count,
    MAX(COUNT_BIG(*)) OVER () AS max_vlf_count
FROM sys.databases AS s
CROSS APPLY sys.dm_db_log_info(s.database_id) AS li
WHERE s.database_id > 4
  AND s.state = 0
  AND s.source_database_id IS NULL
GROUP BY s.name
ORDER BY s.name;
