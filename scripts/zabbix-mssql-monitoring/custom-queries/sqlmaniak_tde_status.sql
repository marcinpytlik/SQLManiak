SET NOCOUNT ON;

SELECT
    d.name AS db,
    COALESCE(dek.encryption_state, 0) AS encryption_state,
    CASE WHEN dek.encryption_state = 3 THEN 1 ELSE 0 END AS encrypted
FROM sys.databases AS d
LEFT JOIN sys.dm_database_encryption_keys AS dek
  ON dek.database_id = d.database_id
WHERE d.database_id > 4
ORDER BY d.name;
